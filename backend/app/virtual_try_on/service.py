import json
from contextlib import ExitStack
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import HTTPException
from loguru import logger
from replicate.client import Client
from replicate.exceptions import ModelError
from sqlmodel import Session

from app.core.config import get_settings
from app.profiles.image_service import profile_image_service
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem

from .model import VirtualTryOnResult


class VirtualTryOnService:
    """Generate and persist virtual try-on results using Replicate."""

    MODEL = "prunaai/p-image-try-on"
    MAX_GARMENTS = 4

    def generate(
        self,
        session: Session,
        profile: Profile,
        items: list[WardrobeItem],
    ) -> VirtualTryOnResult:
        settings = get_settings()

        if not settings.REPLICATE_API_TOKEN:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Virtual Try-On is not configured. "
                    "Add REPLICATE_API_TOKEN to backend/.env."
                ),
            )

        if not profile.avatar_url:
            raise HTTPException(
                status_code=422,
                detail="Add a profile image before using Virtual Try-On.",
            )

        if not items:
            raise HTTPException(
                status_code=422,
                detail="Select at least one wardrobe item before using Virtual Try-On.",
            )

        if len(items) > self.MAX_GARMENTS:
            raise HTTPException(
                status_code=422,
                detail=(
                    f"Virtual Try-On currently supports up to "
                    f"{self.MAX_GARMENTS} garments per request."
                ),
            )

        # Older profiles may not have a VTO asset yet. Generate it lazily and
        # keep it separate from the original profile photo.
        try:
            profile = profile_image_service.ensure_vto_asset(session, profile)
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error

        person_path = self._resolve_local_path(profile.vto_asset_url)

        garment_paths: list[Path] = []
        garment_names: list[str] = []

        for item in items:
            if not item.images:
                raise HTTPException(
                    status_code=422,
                    detail=f'Add an image to "{item.name}" before trying it on.',
                )

            image = sorted(
                item.images,
                key=lambda value: value.display_order,
            )[0]
            garment_paths.append(self._resolve_local_path(image.image_url))
            garment_names.append(item.name)

        prompt = (
            "Dress the supplied person in the supplied wardrobe garments. "
            "The person image has a transparent background and must be treated "
            "as the identity and body reference. Keep the person's face, body "
            "proportions, pose, skin tone and hair consistent. Do not add or "
            "restore the original profile-photo background. "
            f"Use these garments in order: {', '.join(garment_names)}."
        )

        logger.info(
            "Starting Virtual Try-On: profile={} garments={} model={} person_asset={}",
            profile.id,
            garment_names,
            self.MODEL,
            person_path,
        )

        try:
            with ExitStack() as stack:
                person_file = stack.enter_context(person_path.open("rb"))
                garment_files = [
                    stack.enter_context(path.open("rb"))
                    for path in garment_paths
                ]

                client = Client(api_token=settings.REPLICATE_API_TOKEN)
                output = client.run(
                    self.MODEL,
                    input={
                        "person_image": person_file,
                        "garment_images": garment_files,
                        "prompt": prompt,
                        "turbo": len(items) <= 4,
                        "preserve_input_size": True,
                        "output_format": "jpg",
                        "output_quality": 95,
                    },
                    wait=60,
                )

                output_bytes = self._read_output(output)

        except ModelError as error:
            prediction = getattr(error, "prediction", None)
            prediction_id = getattr(prediction, "id", None)
            prediction_status = getattr(prediction, "status", None)
            prediction_error = getattr(prediction, "error", None)
            prediction_logs = getattr(prediction, "logs", None)

            logger.error(
                "Replicate VTO failed: prediction_id={} status={} error={} logs={}",
                prediction_id,
                prediction_status,
                prediction_error,
                prediction_logs,
            )

            detail = prediction_error or str(error)
            if prediction_id:
                detail = f"{detail} (prediction: {prediction_id})"

            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On provider error: {detail}",
            ) from error

        except HTTPException:
            raise
        except Exception as error:
            logger.exception("Unexpected Virtual Try-On failure for profile={}", profile.id)
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On failed while processing the images: {error}",
            ) from error

        if not output_bytes:
            raise HTTPException(
                status_code=502,
                detail="Virtual Try-On completed without returning an image.",
            )

        output_dir = Path("uploads/tryon")
        output_dir.mkdir(parents=True, exist_ok=True)

        filename = f"{profile.id}-{uuid4()}.jpg"
        output_path = output_dir / filename
        output_path.write_bytes(output_bytes)

        result = VirtualTryOnResult(
            profile_id=profile.id,
            image_url=f"/uploads/tryon/{filename}",
            item_ids_json=json.dumps([str(item.id) for item in items]),
        )
        session.add(result)
        session.commit()
        session.refresh(result)

        logger.info(
            "Virtual Try-On completed: profile={} result={} path={}",
            profile.id,
            result.id,
            output_path,
        )

        return result

    @staticmethod
    def _resolve_local_path(value: str | None) -> Path:
        """Resolve the path format used by persisted upload records."""
        raw = (value or "").strip()
        if not raw:
            raise HTTPException(status_code=422, detail="Image path is empty.")

        if raw.startswith(("http://", "https://", "data:")):
            raise HTTPException(
                status_code=422,
                detail=(
                    "Virtual Try-On requires locally stored profile and wardrobe images. "
                    f"Unsupported image reference: {raw}"
                ),
            )

        path = Path(raw)
        if raw.startswith("/uploads/"):
            path = Path(raw.lstrip("/"))

        if not path.is_absolute():
            path = Path.cwd() / path

        path = path.resolve()
        uploads_root = (Path.cwd() / "uploads").resolve()

        try:
            path.relative_to(uploads_root)
        except ValueError as error:
            raise HTTPException(
                status_code=422,
                detail="Image path is outside the application's uploads directory.",
            ) from error

        if not path.exists() or not path.is_file():
            raise HTTPException(
                status_code=422,
                detail=f"Image file is unavailable: {raw}",
            )

        if path.stat().st_size == 0:
            raise HTTPException(
                status_code=422,
                detail=f"Image file is empty: {raw}",
            )

        return path

    @staticmethod
    def _read_output(output) -> bytes:
        """Normalize Replicate SDK file output into bytes."""
        if output is None:
            return b""

        if hasattr(output, "read"):
            return output.read()

        if isinstance(output, (list, tuple)):
            if not output:
                return b""
            first = output[0]
            if hasattr(first, "read"):
                return first.read()
            if isinstance(first, (bytes, bytearray)):
                return bytes(first)

        if isinstance(output, (bytes, bytearray)):
            return bytes(output)

        raise RuntimeError(
            f"Unsupported Replicate output type: {type(output).__name__}"
        )

    @staticmethod
    def to_response(result: VirtualTryOnResult, public_base_url: str):
        from .schema import VirtualTryOnResponse

        return VirtualTryOnResponse(
            id=result.id,
            profile_id=result.profile_id,
            image_url=f"{public_base_url.rstrip('/')}{result.image_url}",
            item_ids=json.loads(result.item_ids_json),
            created_at=result.created_at,
            saved=result.saved,
        )

    def set_saved(
        self,
        session: Session,
        profile: Profile,
        result_id: UUID,
        saved: bool,
    ):
        result = session.get(VirtualTryOnResult, result_id)
        if result is None or result.profile_id != profile.id:
            raise HTTPException(
                status_code=404,
                detail="Virtual Try-On result not found.",
            )

        result.saved = saved
        session.add(result)
        session.commit()
        session.refresh(result)

        from .schema import VirtualTryOnSaveResponse

        return VirtualTryOnSaveResponse(id=result.id, saved=result.saved)

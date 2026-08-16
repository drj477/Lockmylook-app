import json
from io import BytesIO
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import HTTPException
from loguru import logger
from PIL import Image
from replicate.exceptions import ModelError
from sqlmodel import Session

from app.core.config import get_settings
from app.profiles.image_service import profile_image_service
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem

from .gemini_chat.client import (
    GeminiChatAuthenticationError,
    GeminiChatConfigurationError,
)
from .gemini_chat.provider import GeminiChatVirtualTryOnProvider
from .model import VirtualTryOnModel, VirtualTryOnResult
from .providers import ReplicateVirtualTryOnProvider, VirtualTryOnProvider


class VirtualTryOnService:
    """Generate and persist virtual try-on results through selectable providers."""

    MAX_GARMENTS = 4

    def __init__(self) -> None:
        self._gemini_chat_provider: GeminiChatVirtualTryOnProvider | None = None

    async def generate(
        self,
        session: Session,
        profile: Profile,
        items: list[WardrobeItem],
        model: VirtualTryOnModel = VirtualTryOnModel.REPLICATE,
    ) -> VirtualTryOnResult:
        settings = get_settings()

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

        if not profile.vto_asset_url:
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

            image = sorted(item.images, key=lambda value: value.display_order)[0]
            garment_paths.append(self._resolve_local_path(image.image_url))
            garment_names.append(item.name)

        prompt = self._build_prompt(garment_names)
        provider = self._provider(model, settings)

        logger.info(
            "Starting Virtual Try-On: profile={} garments={} model={} person_asset={}",
            profile.id,
            garment_names,
            model.value,
            person_path,
        )

        try:
            output_bytes = await provider.generate(
                person_path=person_path,
                garment_paths=garment_paths,
                garment_names=garment_names,
                prompt=prompt,
            )
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
        except GeminiChatConfigurationError as error:
            raise HTTPException(
                status_code=503,
                detail="Gemini Chat is not configured. Set GEMINI_CHAT_COOKIE_JSON on the backend.",
            ) from error
        except GeminiChatAuthenticationError as error:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Gemini Chat authentication has expired. Re-export the Gemini browser "
                    "cookies and update the server-side cookie JSON."
                ),
            ) from error
        except RuntimeError as error:
            detail = str(error)
            if "REPLICATE_API_TOKEN" in detail:
                raise HTTPException(
                    status_code=503,
                    detail="Replicate Virtual Try-On is not configured. Add REPLICATE_API_TOKEN to backend/.env.",
                ) from error
            logger.exception(
                "Virtual Try-On provider failed: profile={} model={}",
                profile.id,
                model.value,
            )
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On provider error: {detail}",
            ) from error
        except HTTPException:
            raise
        except Exception as error:
            logger.exception(
                "Unexpected Virtual Try-On failure: profile={} model={}",
                profile.id,
                model.value,
            )
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On failed while processing the images: {error}",
            ) from error

        if not output_bytes:
            raise HTTPException(
                status_code=502,
                detail="Virtual Try-On completed without returning an image.",
            )

        output_bytes = self._normalize_output(output_bytes)

        output_dir = Path("uploads/tryon")
        output_dir.mkdir(parents=True, exist_ok=True)

        filename = f"{profile.id}-{uuid4()}.webp"
        output_path = output_dir / filename
        output_path.write_bytes(output_bytes)

        result = VirtualTryOnResult(
            profile_id=profile.id,
            image_url=f"/uploads/tryon/{filename}",
            item_ids_json=json.dumps([str(item.id) for item in items]),
            model=model.value,
        )
        session.add(result)
        session.commit()
        session.refresh(result)

        logger.info(
            "Virtual Try-On completed: profile={} result={} model={} path={}",
            profile.id,
            result.id,
            model.value,
            output_path,
        )

        return result

    def _provider(self, model: VirtualTryOnModel, settings) -> VirtualTryOnProvider:
        if model is VirtualTryOnModel.REPLICATE:
            return ReplicateVirtualTryOnProvider(settings)

        if model is VirtualTryOnModel.GEMINI_CHAT:
            if self._gemini_chat_provider is None:
                self._gemini_chat_provider = GeminiChatVirtualTryOnProvider(settings)
            return self._gemini_chat_provider

        raise HTTPException(status_code=422, detail=f"Unsupported Virtual Try-On model: {model}")

    async def close(self) -> None:
        if self._gemini_chat_provider is not None:
            await self._gemini_chat_provider.close()
            self._gemini_chat_provider = None

    @staticmethod
    def _build_prompt(garment_names: list[str]) -> str:
        garment_list = "\n".join(
            f"- Reference garment image {index + 2}: {name}"
            for index, name in enumerate(garment_names)
        )

        return f"""
Create a photorealistic virtual try-on photograph.

REFERENCE IMAGE 1 is the PERSON. It is authoritative for identity, face, hair,
body proportions, pose, hands, skin, lower body and the original scene.

The remaining reference images are the GARMENTS. Transfer those exact garments
onto the person. Each garment reference is authoritative for its visual design.

{garment_list}

STRICT REQUIREMENTS:
- Preserve the person's identity exactly. Do not regenerate or reinterpret the face.
- Preserve facial structure, hair, skin tone, body proportions and age appearance.
- Preserve the original pose, hands, arms, legs and feet.
- Preserve the original camera perspective and composition.
- Preserve the original background unless a natural adjustment is required for lighting.
- Change clothing only.
- Use the garment references as exact visual references, not inspiration.
- Preserve exact garment color, pattern, print, material, texture, construction and proportions.
- Preserve collars, necklines, buttons, zippers, pockets, seams, cuffs and hems.
- Preserve the complete sleeve length and sleeve construction. Never shorten, remove or crop sleeves.
- Fit each garment naturally to the person's actual body and pose.
- Create realistic fabric folds, tension, occlusion and shadows caused by the pose.
- Keep hands naturally in front of or beside the garments when appropriate.
- Do not add accessories or change unrelated clothing.
- Do not redesign, simplify or invent garment details.
- Do not change the person's gender, hairstyle, facial expression or body shape.
- The result must look like a real photograph of the same person wearing the supplied garments.

Output only the finished image.
""".strip()

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
    def _normalize_output(output_bytes: bytes) -> bytes:
        """Normalize provider output to the app's persisted WebP format."""
        try:
            with Image.open(BytesIO(output_bytes)) as image:
                if image.mode not in ("RGB", "RGBA"):
                    image = image.convert("RGB")
                output = BytesIO()
                image.save(output, format="WEBP", quality=95, method=6)
                return output.getvalue()
        except Exception as error:
            raise RuntimeError(f"Provider returned an unreadable image: {error}") from error

    @staticmethod
    def _read_output(output) -> bytes:
        """Backward-compatible output normalization helper used by tests."""
        if output is None:
            return b""
        if hasattr(output, "read"):
            return output.read()
        if isinstance(output, list | tuple):
            if not output:
                return b""
            first = output[0]
            if hasattr(first, "read"):
                return first.read()
            if isinstance(first, bytes | bytearray):
                return bytes(first)
        if isinstance(output, bytes | bytearray):
            return bytes(output)
        raise RuntimeError(f"Unsupported provider output type: {type(output).__name__}")

    @staticmethod
    def to_response(result: VirtualTryOnResult, public_base_url: str):
        from .schema import VirtualTryOnResponse

        return VirtualTryOnResponse(
            id=result.id,
            profile_id=result.profile_id,
            image_url=f"{public_base_url.rstrip('/')}{result.image_url}",
            item_ids=json.loads(result.item_ids_json),
            model=VirtualTryOnModel(result.model),
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

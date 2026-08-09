import base64
import json
from pathlib import Path
from uuid import UUID

import httpx
from fastapi import HTTPException
from sqlmodel import Session

from app.core.config import get_settings
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem

from .model import VirtualTryOnResult


class VirtualTryOnService:
    MODEL = "prunaai/p-image-try-on"

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

        garment_images: list[str] = []
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

            garment_images.append(self._image_input(image.image_url))
            garment_names.append(item.name)

        human_image = self._image_input(profile.avatar_url)

        prompt = (
            "Dress the person in the supplied wardrobe garments. "
            "Keep the person's face, body proportions, pose, skin tone, "
            "hair and background as consistent as possible. "
            f"Use these garments in order: {', '.join(garment_names)}."
        )

        payload = {
            "input": {
                "person_image": human_image,
                "garment_images": garment_images,
                "prompt": prompt,
                "turbo": len(items) <= 4,
                "preserve_input_size": True,
            }
        }

        headers = {
            "Authorization": f"Bearer {settings.REPLICATE_API_TOKEN}",
            "Content-Type": "application/json",
            "Prefer": "wait=60",
        }

        try:
            with httpx.Client(timeout=75.0) as client:
                response = client.post(
                    f"https://api.replicate.com/v1/models/{self.MODEL}/predictions",
                    headers=headers,
                    json=payload,
                )
                response.raise_for_status()
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On provider error: {error}",
            ) from error

        data = response.json()
        output = data.get("output")

        if not output:
            status = data.get("status", "unknown")
            detail = data.get("error") or (
                "Virtual Try-On did not finish successfully. "
                f"Status: {status}."
            )
            raise HTTPException(status_code=502, detail=detail)

        output_url = output if isinstance(output, str) else output[0]

        try:
            with httpx.Client(timeout=45.0) as client:
                image_response = client.get(output_url)
                image_response.raise_for_status()
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=502,
                detail=f"Could not download the Virtual Try-On result: {error}",
            ) from error

        output_dir = Path("uploads/tryon")
        output_dir.mkdir(parents=True, exist_ok=True)

        import uuid

        filename = f"{profile.id}-{uuid.uuid4()}.png"
        output_path = output_dir / filename
        output_path.write_bytes(image_response.content)

        result = VirtualTryOnResult(
            profile_id=profile.id,
            image_url=f"/uploads/tryon/{filename}",
            item_ids_json=json.dumps([str(item.id) for item in items]),
        )
        session.add(result)
        session.commit()
        session.refresh(result)
        return result

    @staticmethod
    def _image_input(value: str) -> str:
        value = value.strip()

        if value.startswith(("http://", "https://", "data:")):
            return value

        path = Path(value)
        if not path.exists():
            raise HTTPException(
                status_code=422,
                detail=f"Image file is unavailable: {value}",
            )

        data = path.read_bytes()
        if len(data) > 256 * 1024:
            raise HTTPException(
                status_code=422,
                detail=(
                    "A stored image is larger than 256 KB. "
                    "Use a hosted image URL for Virtual Try-On."
                ),
            )

        extension = path.suffix.lower()
        mime = {
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".png": "image/png",
            ".webp": "image/webp",
        }.get(extension, "application/octet-stream")

        encoded = base64.b64encode(data).decode("ascii")
        return f"data:{mime};base64,{encoded}"

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

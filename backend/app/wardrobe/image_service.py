from pathlib import Path
from uuid import UUID, uuid4

from fastapi import UploadFile
from sqlmodel import Session, select

from app.core.exceptions import NotFoundError
from app.wardrobe.garment_background_removal import remove_garment_background
from app.wardrobe.model import WardrobeImage, WardrobeItem

UPLOAD_DIR = Path("uploads/wardrobe")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class ImageService:
    def upload(
        self,
        session: Session,
        item_id: UUID,
        file: UploadFile,
        remove_background: bool = False,
    ) -> WardrobeImage:
        item = session.get(WardrobeItem, item_id)
        if item is None:
            raise NotFoundError("Wardrobe item not found.")

        extension = Path(file.filename or "wardrobe-image.jpg").suffix.lower() or ".jpg"
        raw_bytes = file.file.read()
        if not raw_bytes:
            raise ValueError("Wardrobe image cannot be empty.")

        source_filename = f"{uuid4()}{extension}"
        source_path = UPLOAD_DIR / source_filename
        source_path.write_bytes(raw_bytes)

        image_path = source_path
        original_image_url: str | None = None
        background_removed = False

        try:
            if remove_background:
                processed_bytes = remove_garment_background(raw_bytes)
                processed_filename = f"{uuid4()}.jpg"
                processed_path = UPLOAD_DIR / processed_filename
                processed_path.write_bytes(processed_bytes)
                image_path = processed_path
                original_image_url = str(source_path)
                background_removed = True

            image = WardrobeImage(
                wardrobe_item_id=item.id,
                image_url=str(image_path),
                thumbnail_url=str(image_path),
                original_image_url=original_image_url,
                background_removed=background_removed,
                display_order=0,
            )
            session.add(image)
            session.commit()
            session.refresh(image)
            return image
        except Exception:
            if source_path.exists():
                source_path.unlink()
            if image_path != source_path and image_path.exists():
                image_path.unlink()
            raise

    def list(self, session: Session, item_id: UUID) -> list[WardrobeImage]:
        statement = (
            select(WardrobeImage)
            .where(WardrobeImage.wardrobe_item_id == item_id)
            .order_by(WardrobeImage.display_order)
        )
        return session.exec(statement).all()

    def delete(self, session: Session, image_id: UUID) -> None:
        image = session.get(WardrobeImage, image_id)
        if image is None:
            raise NotFoundError("Image not found.")

        paths = {Path(image.image_url)}
        if image.original_image_url:
            paths.add(Path(image.original_image_url))

        for path in paths:
            if path.exists():
                path.unlink()

        session.delete(image)
        session.commit()

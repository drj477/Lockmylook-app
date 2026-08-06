from pathlib import Path
from uuid import UUID, uuid4

from fastapi import UploadFile
from sqlmodel import Session, select

from app.core.exceptions import NotFoundError
from app.wardrobe.model import (
    WardrobeImage,
    WardrobeItem,
)

UPLOAD_DIR = Path("uploads/wardrobe")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class ImageService:

    def upload(
        self,
        session: Session,
        item_id: UUID,
        file: UploadFile,
    ) -> WardrobeImage:

        item = session.get(
            WardrobeItem,
            item_id,
        )

        if item is None:
            raise NotFoundError("Wardrobe item not found.")

        extension = Path(file.filename).suffix.lower()

        filename = f"{uuid4()}{extension}"

        filepath = UPLOAD_DIR / filename

        with open(filepath, "wb") as buffer:
            buffer.write(file.file.read())

        image = WardrobeImage(
            wardrobe_item_id=item.id,
            image_url=str(filepath),
            thumbnail_url=str(filepath),
            display_order=0,
        )

        session.add(image)
        session.commit()
        session.refresh(image)

        return image

    def list(
        self,
        session: Session,
        item_id: UUID,
    ) -> list[WardrobeImage]:

        statement = (
            select(WardrobeImage)
            .where(
                WardrobeImage.wardrobe_item_id == item_id,
            )
            .order_by(
                WardrobeImage.display_order,
            )
        )

        return session.exec(statement).all()

    def delete(
        self,
        session: Session,
        image_id: UUID,
    ) -> None:

        image = session.get(
            WardrobeImage,
            image_id,
        )

        if image is None:
            raise NotFoundError("Image not found.")

        path = Path(image.image_url)

        if path.exists():
            path.unlink()

        session.delete(image)
        session.commit()
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ImageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    wardrobe_item_id: UUID

    image_url: str
    thumbnail_url: str

    display_order: int
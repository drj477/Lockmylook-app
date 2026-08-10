from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class VirtualTryOnRequest(BaseModel):
    # The currently pinned p-image-try-on API version accepts up to 4 garments.
    item_ids: list[UUID] = Field(min_length=1, max_length=4)


class VirtualTryOnResponse(BaseModel):
    id: UUID
    profile_id: UUID
    image_url: str
    item_ids: list[UUID]
    created_at: datetime
    saved: bool


class VirtualTryOnSaveResponse(BaseModel):
    id: UUID
    saved: bool

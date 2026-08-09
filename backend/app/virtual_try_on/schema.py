from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class VirtualTryOnRequest(BaseModel):
    # The provider recommends up to 6 garments for a clean result.
    item_ids: list[UUID] = Field(min_length=1, max_length=6)


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

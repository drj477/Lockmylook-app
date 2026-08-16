from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from .model import VirtualTryOnModel


class VirtualTryOnRequest(BaseModel):
    item_ids: list[UUID] = Field(min_length=1, max_length=4)
    model: VirtualTryOnModel = VirtualTryOnModel.REPLICATE


class VirtualTryOnResponse(BaseModel):
    id: UUID
    profile_id: UUID
    image_url: str
    item_ids: list[UUID]
    model: VirtualTryOnModel
    created_at: datetime
    saved: bool


class VirtualTryOnSaveResponse(BaseModel):
    id: UUID
    saved: bool

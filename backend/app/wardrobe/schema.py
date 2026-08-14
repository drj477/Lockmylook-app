from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

# ==========================================================
# CREATE
# ==========================================================

class WardrobeCreate(BaseModel):
    category_id: UUID

    name: str
    brand: str | None = None

    primary_color: str | None = None
    secondary_color: str | None = None

    season: str | None = None
    occasion: str | None = None


# ==========================================================
# UPDATE
# ==========================================================

class WardrobeUpdate(BaseModel):
    name: str | None = None
    brand: str | None = None

    primary_color: str | None = None
    secondary_color: str | None = None

    season: str | None = None
    occasion: str | None = None

    favorite: bool | None = None


# ==========================================================
# READ MODELS
# ==========================================================

class WardrobeCategoryInfo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str


class WardrobeImageInfo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    image_url: str
    thumbnail_url: str
    display_order: int


class WardrobeResponse(BaseModel):
    """
    Canonical wardrobe read model.

    Every endpoint that returns wardrobe items
    should reuse this schema.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID

    profile_id: UUID

    name: str
    brand: str | None

    primary_color: str | None
    secondary_color: str | None

    season: str | None
    occasion: str | None

    favorite: bool

    created_at: datetime
    updated_at: datetime

    category: WardrobeCategoryInfo

    images: list[WardrobeImageInfo] = []


# ==========================================================
# SUMMARY
# ==========================================================

class WardrobeSummaryItem(BaseModel):
    category_id: UUID

    category_name: str

    item_count: int

    favorite_count: int

    cover_image: str | None

    last_updated: datetime | None


class WardrobeSummaryResponse(BaseModel):
    success: bool

    message: str

    data: list[WardrobeSummaryItem]

    errors: list[str] = []
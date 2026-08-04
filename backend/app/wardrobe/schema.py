from uuid import UUID

from pydantic import BaseModel


class WardrobeCreate(BaseModel):
    profile_id: UUID
    category_id: UUID

    name: str
    brand: str | None = None

    primary_color: str | None = None
    secondary_color: str | None = None

    season: str | None = None
    occasion: str | None = None


class WardrobeUpdate(BaseModel):
    name: str | None = None
    brand: str | None = None

    primary_color: str | None = None
    secondary_color: str | None = None

    season: str | None = None
    occasion: str | None = None

    favorite: bool | None = None


class WardrobeResponse(BaseModel):
    id: UUID

    profile_id: UUID

    category_id: UUID

    name: str

    brand: str | None

    favorite: bool
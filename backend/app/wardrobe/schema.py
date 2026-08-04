from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class WardrobeCreate(BaseModel):
    category_id: UUID

    name: str = Field(min_length=1, max_length=100)
    brand: str | None = Field(default=None, max_length=100)

    primary_color: str | None = Field(default=None, max_length=50)
    secondary_color: str | None = Field(default=None, max_length=50)

    season: str | None = Field(default=None, max_length=50)
    occasion: str | None = Field(default=None, max_length=50)


class WardrobeUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    brand: str | None = Field(default=None, max_length=100)

    primary_color: str | None = Field(default=None, max_length=50)
    secondary_color: str | None = Field(default=None, max_length=50)

    season: str | None = Field(default=None, max_length=50)
    occasion: str | None = Field(default=None, max_length=50)

    favorite: bool | None = None


class WardrobeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID

    profile_id: UUID
    category_id: UUID

    name: str
    brand: str | None

    primary_color: str | None
    secondary_color: str | None

    season: str | None
    occasion: str | None

    favorite: bool
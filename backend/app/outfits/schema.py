from uuid import UUID

from pydantic import BaseModel, ConfigDict


class OutfitGenerateRequest(BaseModel):
    occasion: str
    season: str | None = None
    mood: str | None = None
    limit: int = 5


class OutfitItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    brand: str | None
    category: str

    primary_color: str | None
    secondary_color: str | None

    season: str | None
    occasion: str | None

    favorite: bool

    image_url: str | None = None


class OutfitSuggestionResponse(BaseModel):
    id: str
    score: float
    reason: str

    items: list[OutfitItemResponse]


class OutfitGenerateResponse(BaseModel):
    occasion: str
    season: str | None
    mood: str | None

    suggestions: list[OutfitSuggestionResponse]

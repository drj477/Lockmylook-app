from uuid import UUID

from pydantic import BaseModel, field_validator


class ProfileCreateRequest(BaseModel):
    name: str
    avatar_url: str | None = None

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Profile name cannot be blank.")
        return value


class ProfileRead(BaseModel):
    id: UUID
    name: str
    avatar_url: str | None
    vto_asset_url: str | None

    model_config = {"from_attributes": True}

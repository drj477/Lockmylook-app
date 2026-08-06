from uuid import UUID

from pydantic import BaseModel, ConfigDict


class CategoryCreate(BaseModel):
    name: str


class CategoryUpdate(BaseModel):
    name: str


class CategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    is_system: bool
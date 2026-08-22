from datetime import UTC, datetime
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import DateTime
from sqlmodel import Field, SQLModel


class VirtualTryOnModel(str, Enum):
    REPLICATE = "replicate"
    GEMINI = "gemini"
    GEMINI_CHAT = "gemini_chat"
    D_TRYON = "d_tryon"


class VirtualTryOnResult(SQLModel, table=True):
    __tablename__ = "virtual_try_on_results"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    profile_id: UUID = Field(foreign_key="profiles.id", index=True, nullable=False)
    image_url: str = Field(nullable=False)
    item_ids_json: str = Field(nullable=False)
    model: str = Field(nullable=False, default=VirtualTryOnModel.REPLICATE.value)
    cache_key: str | None = Field(default=None, max_length=64, index=True)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        nullable=False,
        sa_type=DateTime(timezone=True),
    )
    saved: bool = Field(default=False, nullable=False)

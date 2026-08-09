from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class VirtualTryOnResult(SQLModel, table=True):
    __tablename__ = "virtual_try_on_results"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    profile_id: UUID = Field(foreign_key="profiles.id", index=True, nullable=False)
    image_url: str = Field(nullable=False)
    item_ids_json: str = Field(nullable=False)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    saved: bool = Field(default=False, nullable=False)

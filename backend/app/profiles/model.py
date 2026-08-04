from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class Profile(SQLModel, table=True):
    """A family member's profile under an Account (Netflix-style).
    Public-facing table -> UUID primary key.
    """

    __tablename__ = "profiles"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    account_id: UUID = Field(foreign_key="accounts.id", index=True, nullable=False)
    name: str = Field(nullable=False)
    avatar_url: str | None = Field(default=None)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

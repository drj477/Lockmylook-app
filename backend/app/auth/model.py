from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class Account(SQLModel, table=True):
    """A login identity. One Account can own multiple Profiles
    (Me / Wife / Son / Daughter, Netflix-style).

    Public-facing table -> UUID primary key.
    """

    __tablename__ = "accounts"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    email: str = Field(unique=True, index=True, nullable=False)
    hashed_password: str = Field(nullable=False)
    is_active: bool = Field(default=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))

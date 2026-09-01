from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, UniqueConstraint
from sqlmodel import Field, SQLModel


class AuthSession(SQLModel, table=True):
    """Server-side authentication session.

    Only a hash of the refresh token is stored. The session ID is embedded in
    both access and refresh JWTs so revoking the session immediately revokes
    both token types without storing bearer tokens themselves.
    """

    __tablename__ = "auth_sessions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    account_id: UUID = Field(foreign_key="accounts.id", index=True, nullable=False)
    refresh_token_hash: str = Field(unique=True, index=True, nullable=False, max_length=64)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
    )
    expires_at: datetime = Field(sa_type=DateTime(timezone=True), nullable=False)
    last_used_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
    )
    revoked_at: datetime | None = Field(default=None, sa_type=DateTime(timezone=True))
    ip_hash: str | None = Field(default=None, max_length=64)
    user_agent: str | None = Field(default=None, max_length=512)


class AuthThrottle(SQLModel, table=True):
    """Persistent login/signup throttling buckets.

    Keys are HMACs rather than raw IP addresses or email addresses. The table
    is intentionally small and is cleaned opportunistically when a bucket is
    reused.
    """

    __tablename__ = "auth_throttles"
    __table_args__ = (UniqueConstraint("scope", "key_hash", name="ux_auth_throttle_scope_key"),)

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    scope: str = Field(max_length=32, nullable=False)
    key_hash: str = Field(max_length=64, nullable=False)
    attempts: int = Field(default=0, nullable=False)
    window_started_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
    )
    blocked_until: datetime | None = Field(default=None, sa_type=DateTime(timezone=True))
    last_attempt_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
    )

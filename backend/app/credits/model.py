from datetime import UTC, datetime
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import DateTime
from sqlmodel import Field, SQLModel


class CreditTransactionType(str, Enum):
    PURCHASE = "purchase"
    GENERATION = "generation"
    CACHE_HIT = "cache_hit"
    REFUND = "refund"
    ADJUSTMENT = "adjustment"


class CreditTransaction(SQLModel, table=True):
    """Immutable audit entry for every credit movement.

    Credit amounts are stored as half-credit units so 0.5 credits is represented
    by the integer 1. This avoids floating-point accounting errors.
    """

    __tablename__ = "credit_transactions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    account_id: UUID = Field(foreign_key="accounts.id", index=True, nullable=False)
    units_delta: int = Field(nullable=False)
    balance_after_units: int = Field(nullable=False)
    transaction_type: str = Field(nullable=False, max_length=32)
    reason: str = Field(nullable=False, max_length=128)
    provider: str | None = Field(default=None, max_length=32)
    vto_result_id: UUID | None = Field(default=None, index=True)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        nullable=False,
        sa_type=DateTime(timezone=True),
    )

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime
from sqlmodel import Field, SQLModel


class PurchaseStatus:
    """Persisted purchase lifecycle states."""

    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"
    REFUNDED = "refunded"


class CreditPurchase(SQLModel, table=True):
    """Immutable purchase record plus payment-provider state.

    Credit amounts and INR amounts are snapshotted on the purchase so later
    package-price changes cannot alter the meaning of an existing order.
    Credits are granted only after a verified payment transitions to PAID.
    """

    __tablename__ = "credit_purchases"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    account_id: UUID = Field(foreign_key="accounts.id", index=True, nullable=False)

    # Snapshot of the package selected at checkout.
    package_code: str = Field(nullable=False, max_length=64)
    credits: int = Field(nullable=False)
    amount_paise: int = Field(nullable=False)
    currency: str = Field(default="INR", nullable=False, max_length=3)

    status: str = Field(
        default=PurchaseStatus.PENDING,
        nullable=False,
        max_length=16,
    )

    # Filled only when a payment provider is actually integrated.
    payment_provider: str | None = Field(default=None, max_length=32)
    provider_order_id: str | None = Field(default=None, max_length=128, unique=True)
    provider_payment_id: str | None = Field(default=None, max_length=128, unique=True)
    provider_signature: str | None = Field(default=None, max_length=512)

    # Client-generated idempotency key for safe order creation retries.
    idempotency_key: str | None = Field(default=None, max_length=128, unique=True)

    failure_reason: str | None = Field(default=None, max_length=512)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        nullable=False,
        sa_type=DateTime(timezone=True),
    )
    paid_at: datetime | None = Field(
        default=None,
        sa_type=DateTime(timezone=True),
    )
    refunded_at: datetime | None = Field(
        default=None,
        sa_type=DateTime(timezone=True),
    )

"""add credit purchase records

Revision ID: 20260825_credit_purchases
Revises: 20260825_credits
Create Date: 2026-08-25
"""

import sqlalchemy as sa

from alembic import op

revision = "20260825_credit_purchases"
down_revision = "20260825_credits"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "credit_purchases",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("package_code", sa.String(length=64), nullable=False),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column("amount_paise", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("payment_provider", sa.String(length=32), nullable=True),
        sa.Column("provider_order_id", sa.String(length=128), nullable=True),
        sa.Column("provider_payment_id", sa.String(length=128), nullable=True),
        sa.Column("provider_signature", sa.String(length=512), nullable=True),
        sa.Column("idempotency_key", sa.String(length=128), nullable=True),
        sa.Column("failure_reason", sa.String(length=512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("refunded_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_credit_purchases_account_id",
        "credit_purchases",
        ["account_id"],
        unique=False,
    )
    op.create_index(
        "ux_credit_purchases_provider_order_id",
        "credit_purchases",
        ["provider_order_id"],
        unique=True,
    )
    op.create_index(
        "ux_credit_purchases_provider_payment_id",
        "credit_purchases",
        ["provider_payment_id"],
        unique=True,
    )
    op.create_index(
        "ux_credit_purchases_idempotency_key",
        "credit_purchases",
        ["idempotency_key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ux_credit_purchases_idempotency_key", table_name="credit_purchases")
    op.drop_index("ux_credit_purchases_provider_payment_id", table_name="credit_purchases")
    op.drop_index("ux_credit_purchases_provider_order_id", table_name="credit_purchases")
    op.drop_index("ix_credit_purchases_account_id", table_name="credit_purchases")
    op.drop_table("credit_purchases")

"""add credit balance and transaction ledger

Revision ID: 20260825_credits
Revises: 20260824_unique_vto_cache
Create Date: 2026-08-25
"""

import sqlalchemy as sa

from alembic import op

revision = "20260825_credits"
down_revision = "20260824_unique_vto_cache"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "accounts",
        sa.Column("credit_units", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_table(
        "credit_transactions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("units_delta", sa.Integer(), nullable=False),
        sa.Column("balance_after_units", sa.Integer(), nullable=False),
        sa.Column("transaction_type", sa.String(length=32), nullable=False),
        sa.Column("reason", sa.String(length=128), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=True),
        sa.Column("vto_result_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_credit_transactions_account_id",
        "credit_transactions",
        ["account_id"],
        unique=False,
    )
    op.create_index(
        "ix_credit_transactions_vto_result_id",
        "credit_transactions",
        ["vto_result_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_credit_transactions_vto_result_id", table_name="credit_transactions")
    op.drop_index("ix_credit_transactions_account_id", table_name="credit_transactions")
    op.drop_table("credit_transactions")
    op.drop_column("accounts", "credit_units")

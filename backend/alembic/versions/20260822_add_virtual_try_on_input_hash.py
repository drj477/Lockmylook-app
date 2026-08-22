"""add persistent virtual try-on cache key

Revision ID: 20260822_vto_cache
Revises: c82d98a56048
Create Date: 2026-08-22
"""

import sqlalchemy as sa

from alembic import op

revision = "20260822_vto_cache"
down_revision = "c82d98a56048"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "virtual_try_on_results",
        sa.Column("input_hash", sa.String(), nullable=True),
    )
    op.create_index(
        "ix_virtual_try_on_results_input_hash",
        "virtual_try_on_results",
        ["input_hash"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_virtual_try_on_results_input_hash",
        table_name="virtual_try_on_results",
    )
    op.drop_column("virtual_try_on_results", "input_hash")

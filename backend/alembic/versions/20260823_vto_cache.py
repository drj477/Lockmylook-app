"""add persistent virtual try-on cache key

Revision ID: 20260823_vto_cache
Revises: c82d98a56048
Create Date: 2026-08-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20260823_vto_cache"
down_revision = "c82d98a56048"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "virtual_try_on_results",
        sa.Column("cache_key", sa.String(length=64), nullable=True),
    )
    op.create_index(
        "ix_virtual_try_on_results_cache_key",
        "virtual_try_on_results",
        ["cache_key"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_virtual_try_on_results_cache_key",
        table_name="virtual_try_on_results",
    )
    op.drop_column("virtual_try_on_results", "cache_key")

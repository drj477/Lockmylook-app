"""make VTO cache unique per profile and visual input

Revision ID: 20260824_unique_vto_cache
Revises: 20260823_vto_cache
Create Date: 2026-08-24
"""

import sqlalchemy as sa

from alembic import op

revision = "20260824_unique_vto_cache"
down_revision = "20260823_vto_cache"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # One visual request may have only one persisted result for a profile.
    # The cache key intentionally excludes the generation model/provider.
    op.create_index(
        "ux_virtual_try_on_results_profile_cache_key",
        "virtual_try_on_results",
        ["profile_id", "cache_key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ux_virtual_try_on_results_profile_cache_key",
        table_name="virtual_try_on_results",
    )

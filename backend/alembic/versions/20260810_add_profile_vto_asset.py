"""add separate VTO profile asset

Revision ID: 20260810_profile_vto_asset
Revises: 20260810_vto
Create Date: 2026-08-10
"""

import sqlalchemy as sa

from alembic import op

revision = "20260810_profile_vto_asset"
down_revision = "20260810_vto"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "profiles",
        sa.Column("vto_asset_url", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("profiles", "vto_asset_url")

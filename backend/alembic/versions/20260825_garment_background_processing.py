"""add optional garment background processing metadata

Revision ID: 20260825_garment_background_processing
Revises: 20260825_credit_purchases
Create Date: 2026-08-25
"""

import sqlalchemy as sa

from alembic import op

revision = "20260825_garment_background_processing"
down_revision = "20260825_credit_purchases"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "wardrobe_images",
        sa.Column("original_image_url", sa.String(), nullable=True),
    )
    op.add_column(
        "wardrobe_images",
        sa.Column(
            "background_removed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.alter_column(
        "wardrobe_images",
        "background_removed",
        server_default=None,
    )


def downgrade() -> None:
    op.drop_column("wardrobe_images", "background_removed")
    op.drop_column("wardrobe_images", "original_image_url")

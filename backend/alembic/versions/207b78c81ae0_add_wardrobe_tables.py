"""add wardrobe tables

Revision ID: 207b78c81ae0
Revises: 0001
Create Date: 2026-08-05 15:34:11.675327

"""

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel
from alembic import op

revision: str = "207b78c81ae0"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "wardrobe_categories",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "name",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_wardrobe_categories_name"),
        "wardrobe_categories",
        ["name"],
        unique=True,
    )

    op.create_table(
        "wardrobe_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("profile_id", sa.Uuid(), nullable=False),
        sa.Column("category_id", sa.Uuid(), nullable=False),
        sa.Column(
            "name",
            sqlmodel.sql.sqltypes.AutoString(length=100),
            nullable=False,
        ),
        sa.Column(
            "brand",
            sqlmodel.sql.sqltypes.AutoString(length=100),
            nullable=True,
        ),
        sa.Column(
            "primary_color",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=True,
        ),
        sa.Column(
            "secondary_color",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=True,
        ),
        sa.Column(
            "season",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=True,
        ),
        sa.Column(
            "occasion",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=True,
        ),
        sa.Column(
            "favorite",
            sa.Boolean(),
            nullable=False,
        ),
        sa.Column(
            "is_deleted",
            sa.Boolean(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["wardrobe_categories.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_wardrobe_items_profile_id"),
        "wardrobe_items",
        ["profile_id"],
        unique=False,
    )

    op.create_index(
        op.f("ix_wardrobe_items_category_id"),
        "wardrobe_items",
        ["category_id"],
        unique=False,
    )

    op.create_table(
        "wardrobe_images",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "wardrobe_item_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "image_url",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column(
            "thumbnail_url",
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column(
            "display_order",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["wardrobe_item_id"],
            ["wardrobe_items.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_wardrobe_images_wardrobe_item_id"),
        "wardrobe_images",
        ["wardrobe_item_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_wardrobe_images_wardrobe_item_id"),
        table_name="wardrobe_images",
    )

    op.drop_table("wardrobe_images")

    op.drop_index(
        op.f("ix_wardrobe_items_profile_id"),
        table_name="wardrobe_items",
    )

    op.drop_index(
        op.f("ix_wardrobe_items_category_id"),
        table_name="wardrobe_items",
    )

    op.drop_table("wardrobe_items")

    op.drop_index(
        op.f("ix_wardrobe_categories_name"),
        table_name="wardrobe_categories",
    )

    op.drop_table("wardrobe_categories")
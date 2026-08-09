"""add virtual try-on results

Revision ID: 20260810_vto
Revises: 9f750f6d5ad4
Create Date: 2026-08-10
"""

from alembic import op
import sqlalchemy as sa


revision = "20260810_vto"
down_revision = "9f750f6d5ad4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "virtual_try_on_results",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("profile_id", sa.Uuid(), nullable=False),
        sa.Column("image_url", sa.String(), nullable=False),
        sa.Column("item_ids_json", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("saved", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_virtual_try_on_results_profile_id",
        "virtual_try_on_results",
        ["profile_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_virtual_try_on_results_profile_id",
        table_name="virtual_try_on_results",
    )
    op.drop_table("virtual_try_on_results")

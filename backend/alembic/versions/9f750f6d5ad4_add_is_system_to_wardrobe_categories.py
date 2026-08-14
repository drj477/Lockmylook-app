"""add is_system to wardrobe categories

Revision ID: 9f750f6d5ad4
Revises: 207b78c81ae0
Create Date: 2026-08-05 21:19:53.090062

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "9f750f6d5ad4"
down_revision: str | None = "207b78c81ae0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "wardrobe_categories",
        sa.Column(
            "is_system",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column(
        "wardrobe_categories",
        "is_system",
    )
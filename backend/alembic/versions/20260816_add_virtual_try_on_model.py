"""add virtual try-on model selection

Revision ID: 20260816_vto_model
Revises: 20260810_vto
Create Date: 2026-08-16
"""

import sqlalchemy as sa

from alembic import op

revision = "20260816_vto_model"
down_revision = "20260810_vto"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "virtual_try_on_results",
        sa.Column(
            "model",
            sa.String(),
            nullable=False,
            server_default="replicate",
        ),
    )


def downgrade() -> None:
    op.drop_column("virtual_try_on_results", "model")

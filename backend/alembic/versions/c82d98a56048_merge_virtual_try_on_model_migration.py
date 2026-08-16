"""merge virtual try-on model migration

Revision ID: c82d98a56048
Revises: 20260816_vto_model, <NEW_REVISION_ID>
Create Date: 2026-08-16 22:03:48.302312

"""
from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel
from alembic import op


revision: str = 'c82d98a56048'
down_revision: str | None = ('20260816_vto_model', '<NEW_REVISION_ID>')
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass

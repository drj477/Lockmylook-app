"""update system categories

Revision ID: <NEW_REVISION_ID>
Revises: 20260810_profile_vto_asset
"""


from alembic import op

revision = "<NEW_REVISION_ID>"
down_revision = "20260810_profile_vto_asset"
branch_labels = None
depends_on = None


def upgrade() -> None:

    # Rename existing categories
    op.execute("""
        UPDATE wardrobe_categories
        SET name='Footwear'
        WHERE name='Shoes';
    """)

    op.execute("""
        UPDATE wardrobe_categories
        SET name='Socks & Hosiery'
        WHERE name='Socks';
    """)

    # Insert new categories
    op.execute("""
        INSERT INTO wardrobe_categories
            (id, name, is_system, created_at)
        SELECT
            gen_random_uuid(),
            'Dresses & Jumpsuits',
            TRUE,
            NOW()
        WHERE NOT EXISTS (
            SELECT 1
            FROM wardrobe_categories
            WHERE name='Dresses & Jumpsuits'
        );
    """)

    op.execute("""
        INSERT INTO wardrobe_categories
            (id, name, is_system, created_at)
        SELECT
            gen_random_uuid(),
            'Sleepwear',
            TRUE,
            NOW()
        WHERE NOT EXISTS (
            SELECT 1
            FROM wardrobe_categories
            WHERE name='Sleepwear'
        );
    """)

    op.execute("""
        INSERT INTO wardrobe_categories
            (id, name, is_system, created_at)
        SELECT
            gen_random_uuid(),
            'Activewear & Swimwear',
            TRUE,
            NOW()
        WHERE NOT EXISTS (
            SELECT 1
            FROM wardrobe_categories
            WHERE name='Activewear & Swimwear'
        );
    """)

    op.execute("""
        INSERT INTO wardrobe_categories
            (id, name, is_system, created_at)
        SELECT
            gen_random_uuid(),
            'Ethnic Wear',
            TRUE,
            NOW()
        WHERE NOT EXISTS (
            SELECT 1
            FROM wardrobe_categories
            WHERE name='Ethnic Wear'
        );
    """)


def downgrade() -> None:

    op.execute("""
        UPDATE wardrobe_categories
        SET name='Shoes'
        WHERE name='Footwear';
    """)

    op.execute("""
        UPDATE wardrobe_categories
        SET name='Socks'
        WHERE name='Socks & Hosiery';
    """)

    op.execute("""
        DELETE FROM wardrobe_categories
        WHERE name IN (
            'Dresses & Jumpsuits',
            'Sleepwear',
            'Activewear & Swimwear',
            'Ethnic Wear'
        );
    """)
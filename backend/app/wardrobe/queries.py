from uuid import UUID

from sqlalchemy.orm import selectinload
from sqlmodel import Session, select

from app.core.exceptions import NotFoundError
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem


class WardrobeQueries:
    """
    Read-only queries for the wardrobe module.

    All GET endpoints should use this class.

    No inserts, updates or deletes belong here.
    """

    def list_items(
        self,
        session: Session,
        profile: Profile,
    ) -> list[WardrobeItem]:

        statement = (
            select(WardrobeItem)
            .where(
                WardrobeItem.profile_id == profile.id,
                WardrobeItem.is_deleted.is_(False),
            )
            .options(
                selectinload(WardrobeItem.category),
                selectinload(WardrobeItem.images),
            )
            .order_by(WardrobeItem.created_at.desc())
        )

        return list(session.exec(statement))

    def get_item(
        self,
        session: Session,
        profile: Profile,
        item_id: UUID,
    ) -> WardrobeItem:

        statement = (
            select(WardrobeItem)
            .where(
                WardrobeItem.id == item_id,
                WardrobeItem.profile_id == profile.id,
                WardrobeItem.is_deleted.is_(False),
            )
            .options(
                selectinload(WardrobeItem.category),
                selectinload(WardrobeItem.images),
            )
        )

        item = session.exec(statement).first()

        if item is None:
            raise NotFoundError(
                "Wardrobe item not found."
            )

        # Always keep images ordered
        item.images.sort(
            key=lambda image: image.display_order
        )

        return item

    def list_favorites(
        self,
        session: Session,
        profile: Profile,
    ) -> list[WardrobeItem]:

        statement = (
            select(WardrobeItem)
            .where(
                WardrobeItem.profile_id == profile.id,
                WardrobeItem.favorite.is_(True),
                WardrobeItem.is_deleted.is_(False),
            )
            .options(
                selectinload(WardrobeItem.category),
                selectinload(WardrobeItem.images),
            )
            .order_by(WardrobeItem.updated_at.desc())
        )

        items = list(session.exec(statement))

        for item in items:
            item.images.sort(
                key=lambda image: image.display_order
            )

        return items

    # =====================================================
    # Future Query APIs
    # =====================================================

    def wardrobe_summary(
        self,
        session: Session,
        profile: Profile,
    ):
        """
        Sprint 4.2

        Implemented next.
        """
        raise NotImplementedError

    def gallery(
        self,
        session: Session,
        profile: Profile,
    ):
        """
        Sprint 4.3
        """
        raise NotImplementedError

    def search(
        self,
        session: Session,
        profile: Profile,
        query: str,
    ):
        """
        Sprint 4.4
        """
        raise NotImplementedError

    def filter_items(
        self,
        session: Session,
        profile: Profile,
    ):
        """
        Sprint 4.5
        """
        raise NotImplementedError
from datetime import datetime, timezone
from uuid import UUID

from sqlmodel import Session, select

from app.core.exceptions import NotFoundError
from app.profiles.model import Profile

from .model import (
    WardrobeCategory,
    WardrobeItem,
)
from .schema import (
    WardrobeCreate,
    WardrobeUpdate,
)


class WardrobeService:

    def create(
        self,
        session: Session,
        profile: Profile,
        payload: WardrobeCreate,
    ) -> WardrobeItem:

        category = session.get(
            WardrobeCategory,
            payload.category_id,
        )

        if category is None:
            raise NotFoundError("Wardrobe category not found.")

        item = WardrobeItem(
            profile_id=profile.id,
            category_id=payload.category_id,
            name=payload.name,
            brand=payload.brand,
            primary_color=payload.primary_color,
            secondary_color=payload.secondary_color,
            season=payload.season,
            occasion=payload.occasion,
        )

        session.add(item)
        session.commit()
        session.refresh(item)

        return item

    def list(
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
            .order_by(WardrobeItem.created_at.desc())
        )

        return session.exec(statement).all()

    def get(
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
        )

        item = session.exec(statement).first()

        if item is None:
            raise NotFoundError("Wardrobe item not found.")

        return item

    def update(
        self,
        session: Session,
        profile: Profile,
        item_id: UUID,
        payload: WardrobeUpdate,
    ) -> WardrobeItem:

        item = self.get(
            session=session,
            profile=profile,
            item_id=item_id,
        )

        updates = payload.model_dump(exclude_unset=True)

        for field, value in updates.items():
            setattr(item, field, value)

        item.updated_at = datetime.now(timezone.utc)

        session.add(item)
        session.commit()
        session.refresh(item)

        return item

    def delete(
        self,
        session: Session,
        profile: Profile,
        item_id: UUID,
    ) -> None:

        item = self.get(
            session=session,
            profile=profile,
            item_id=item_id,
        )

        item.is_deleted = True
        item.updated_at = datetime.now(timezone.utc)

        session.add(item)
        session.commit()
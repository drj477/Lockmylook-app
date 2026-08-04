from uuid import UUID

from sqlmodel import Session, select

from .model import WardrobeItem
from .schema import WardrobeCreate


class WardrobeService:

    def create(
        self,
        session: Session,
        payload: WardrobeCreate,
    ) -> WardrobeItem:

        item = WardrobeItem.model_validate(payload)

        session.add(item)

        session.commit()

        session.refresh(item)

        return item

    def list(
        self,
        session: Session,
        profile_id: UUID,
    ):

        statement = (
            select(WardrobeItem)
            .where(
                WardrobeItem.profile_id == profile_id,
                WardrobeItem.is_deleted == False,
            )
        )

        return session.exec(statement).all()
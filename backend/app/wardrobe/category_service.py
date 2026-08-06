from uuid import UUID

from sqlmodel import Session, select

from app.core.exceptions import (
    ConflictError,
    NotFoundError,
)
from app.wardrobe.category_schema import (
    CategoryCreate,
    CategoryUpdate,
)
from app.wardrobe.model import WardrobeCategory


def create_category(
    session: Session,
    payload: CategoryCreate,
) -> WardrobeCategory:

    existing = session.exec(
        select(WardrobeCategory).where(
            WardrobeCategory.name == payload.name
        )
    ).first()

    if existing:
        raise ConflictError("Category already exists.")

    category = WardrobeCategory(
        name=payload.name,
        is_system=False,
    )

    session.add(category)
    session.commit()
    session.refresh(category)

    return category


def list_categories(
    session: Session,
) -> list[WardrobeCategory]:

    statement = (
        select(WardrobeCategory)
        .order_by(WardrobeCategory.name)
    )

    return list(session.exec(statement))


def get_category(
    session: Session,
    category_id: UUID,
) -> WardrobeCategory:

    category = session.get(
        WardrobeCategory,
        category_id,
    )

    if category is None:
        raise NotFoundError("Category not found.")

    return category


def update_category(
    session: Session,
    category_id: UUID,
    payload: CategoryUpdate,
) -> WardrobeCategory:

    category = get_category(
        session,
        category_id,
    )

    if category.is_system:
        raise ConflictError(
            "System categories cannot be renamed."
        )

    existing = session.exec(
        select(WardrobeCategory).where(
            WardrobeCategory.name == payload.name,
            WardrobeCategory.id != category.id,
        )
    ).first()

    if existing:
        raise ConflictError("Category already exists.")

    category.name = payload.name

    session.add(category)
    session.commit()
    session.refresh(category)

    return category


def delete_category(
    session: Session,
    category_id: UUID,
) -> None:

    category = get_category(
        session,
        category_id,
    )

    if category.is_system:
        raise ConflictError(
            "System categories cannot be deleted."
        )

    session.delete(category)
    session.commit()
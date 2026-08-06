from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlmodel import Session

from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.core.schema import Envelope
from app.database.session import get_session
from app.wardrobe import category_service
from app.wardrobe.category_schema import (
    CategoryCreate,
    CategoryRead,
    CategoryUpdate,
)

router = APIRouter(
    prefix="/wardrobe/categories",
    tags=["Wardrobe Categories"],
)


@router.post(
    "",
    response_model=Envelope[CategoryRead],
    status_code=status.HTTP_201_CREATED,
)
async def create_category(
    request: CategoryCreate,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[CategoryRead]:
    category = category_service.create_category(
        session=session,
        payload=request,
    )

    return Envelope(
        message="Category created successfully.",
        data=CategoryRead.model_validate(category),
    )


@router.get(
    "",
    response_model=Envelope[list[CategoryRead]],
)
async def list_categories(
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[list[CategoryRead]]:
    categories = category_service.list_categories(session)

    return Envelope(
        message="Categories retrieved successfully.",
        data=[
            CategoryRead.model_validate(category)
            for category in categories
        ],
    )


@router.get(
    "/{category_id}",
    response_model=Envelope[CategoryRead],
)
async def get_category(
    category_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[CategoryRead]:
    category = category_service.get_category(
        session=session,
        category_id=category_id,
    )

    return Envelope(
        message="Category retrieved successfully.",
        data=CategoryRead.model_validate(category),
    )


@router.patch(
    "/{category_id}",
    response_model=Envelope[CategoryRead],
)
async def update_category(
    category_id: UUID,
    request: CategoryUpdate,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[CategoryRead]:
    category = category_service.update_category(
        session=session,
        category_id=category_id,
        payload=request,
    )

    return Envelope(
        message="Category updated successfully.",
        data=CategoryRead.model_validate(category),
    )


@router.delete(
    "/{category_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_category(
    category_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> None:
    category_service.delete_category(
        session=session,
        category_id=category_id,
    )
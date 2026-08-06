from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlmodel import Session

from app.database.session import get_session
from app.profiles.dependencies import get_owned_profile
from app.profiles.model import Profile

from .schema import (
    WardrobeCreate,
    WardrobeResponse,
    WardrobeUpdate,
)
from .service import WardrobeService

router = APIRouter(
    tags=["Wardrobe"],
)

service = WardrobeService()


@router.post(
    "/profiles/{profile_id}/wardrobe",
    response_model=WardrobeResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_item(
    payload: WardrobeCreate,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):

    return service.create(
        session=session,
        profile=owned_profile,
        payload=payload,
    )


@router.get(
    "/profiles/{profile_id}/wardrobe",
    response_model=list[WardrobeResponse],
)
def list_items(
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):

    return service.list(
        session=session,
        profile=owned_profile,
    )


@router.get(
    "/profiles/{profile_id}/wardrobe/{item_id}",
    response_model=WardrobeResponse,
)
def get_item(
    item_id: UUID,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):

    return service.get(
        session=session,
        profile=owned_profile,
        item_id=item_id,
    )


@router.patch(
    "/profiles/{profile_id}/wardrobe/{item_id}",
    response_model=WardrobeResponse,
)
def update_item(
    item_id: UUID,
    payload: WardrobeUpdate,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):

    return service.update(
        session=session,
        profile=owned_profile,
        item_id=item_id,
        payload=payload,
    )


@router.delete(
    "/profiles/{profile_id}/wardrobe/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_item(
    item_id: UUID,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):

    service.delete(
        session=session,
        profile=owned_profile,
        item_id=item_id,
    )
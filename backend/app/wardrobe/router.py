from fastapi import APIRouter, Depends

from sqlmodel import Session

from app.database.session import get_session

from .schema import (
    WardrobeCreate,
    WardrobeResponse,
)

from .service import WardrobeService

router = APIRouter(
    prefix="/wardrobe",
    tags=["Wardrobe"],
)

service = WardrobeService()


@router.post(
    "",
    response_model=WardrobeResponse,
)
def create_item(
    payload: WardrobeCreate,
    session: Session = Depends(get_session),
):

    return service.create(session, payload)


@router.get("/{profile_id}")
def list_items(
    profile_id,
    session: Session = Depends(get_session),
):

    return service.list(
        session,
        profile_id,
    )
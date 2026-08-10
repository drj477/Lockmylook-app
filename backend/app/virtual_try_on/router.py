from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlmodel import Session, select

from app.database.session import get_session
from app.profiles.dependencies import get_owned_profile
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem

from .schema import (
    VirtualTryOnRequest,
    VirtualTryOnResponse,
    VirtualTryOnSaveResponse,
)
from .service import VirtualTryOnService

router = APIRouter(tags=["Virtual Try-On"])
service = VirtualTryOnService()


@router.post(
    "/profiles/{profile_id}/try-on",
    response_model=VirtualTryOnResponse,
)
def generate_try_on(
    payload: VirtualTryOnRequest,
    request: Request,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):
    items = session.exec(
        select(WardrobeItem).where(
            WardrobeItem.profile_id == owned_profile.id,
            WardrobeItem.is_deleted.is_(False),
            WardrobeItem.id.in_(payload.item_ids),
        )
    ).all()

    if len(items) != len(set(payload.item_ids)):
        raise HTTPException(
            status_code=404,
            detail="One or more selected wardrobe items were not found.",
        )

    ordered_items = {item.id: item for item in items}
    selected_items = [ordered_items[item_id] for item_id in payload.item_ids]

    result = service.generate(
        session=session,
        profile=owned_profile,
        items=selected_items,
    )

    return service.to_response(
        result,
        str(request.base_url).rstrip("/"),
    )


@router.patch(
    "/profiles/{profile_id}/try-on/{result_id}/save",
    response_model=VirtualTryOnSaveResponse,
)
def save_try_on(
    result_id: UUID,
    saved: bool = True,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):
    return service.set_saved(
        session=session,
        profile=owned_profile,
        result_id=result_id,
        saved=saved,
    )

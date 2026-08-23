import json
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlmodel import Session, select

from app.database.session import get_session
from app.profiles.dependencies import get_owned_profile
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem

from .model import VirtualTryOnResult
from .schema import (
    VirtualTryOnRequest,
    VirtualTryOnResponse,
    VirtualTryOnSaveResponse,
)
from .service import VirtualTryOnService

router = APIRouter(tags=["Virtual Try-On"])
service = VirtualTryOnService()


def _to_response(result: VirtualTryOnResult, base_url: str) -> dict:
    image_url = result.image_url
    if image_url.startswith("/"):
        image_url = f"{base_url.rstrip('/')}{image_url}"
    return {
        "id": result.id,
        "profile_id": result.profile_id,
        "image_url": image_url,
        "item_ids": json.loads(result.item_ids_json),
        "model": result.model,
        "created_at": result.created_at,
        "saved": result.saved,
    }


@router.post(
    "/profiles/{profile_id}/try-on",
    response_model=VirtualTryOnResponse,
)
async def generate_try_on(
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

    result = await service.generate(
        session=session,
        profile=owned_profile,
        items=selected_items,
        model=payload.model,
    )

    return service.to_response(result, str(request.base_url).rstrip("/"))


@router.get(
    "/profiles/{profile_id}/try-on/history",
    response_model=list[VirtualTryOnResponse],
)
def get_try_on_history(
    request: Request,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):
    results = session.exec(
        select(VirtualTryOnResult)
        .where(VirtualTryOnResult.profile_id == owned_profile.id)
        .order_by(VirtualTryOnResult.created_at.desc())
    ).all()

    return [_to_response(result, str(request.base_url).rstrip("/")) for result in results]


@router.delete("/profiles/{profile_id}/try-on/cache")
def delete_all_try_on_cache(
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):
    results = session.exec(
        select(VirtualTryOnResult).where(
            VirtualTryOnResult.profile_id == owned_profile.id,
        )
    ).all()

    for result in results:
        if result.image_url.startswith("/uploads/"):
            path = (Path.cwd() / result.image_url.lstrip("/")).resolve()
            uploads_root = (Path.cwd() / "uploads").resolve()
            try:
                path.relative_to(uploads_root)
                if path.is_file():
                    path.unlink()
            except ValueError:
                pass

        # cache_key lives on the result row, so deleting the row removes
        # the corresponding cache entry as well.
        session.delete(result)

    session.commit()
    return {"deleted": len(results)}


@router.delete("/profiles/{profile_id}/try-on/{result_id}")
def delete_try_on_result(
    result_id: UUID,
    owned_profile: Profile = Depends(get_owned_profile),
    session: Session = Depends(get_session),
):
    result = session.exec(
        select(VirtualTryOnResult).where(
            VirtualTryOnResult.id == result_id,
            VirtualTryOnResult.profile_id == owned_profile.id,
        )
    ).first()

    if result is None:
        raise HTTPException(status_code=404, detail="Virtual Try-On result not found.")

    if result.image_url.startswith("/uploads/"):
        path = (Path.cwd() / result.image_url.lstrip("/")).resolve()
        uploads_root = (Path.cwd() / "uploads").resolve()
        try:
            path.relative_to(uploads_root)
            if path.is_file():
                path.unlink()
        except ValueError:
            pass

    # cache_key is stored on this same row; deleting the result deletes the
    # selective cache key together with the generated image.
    session.delete(result)
    session.commit()

    return {"deleted": True, "result_id": result_id}


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

from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.database.session import get_session
from app.profiles.dependencies import get_owned_profile
from app.profiles.model import Profile

from .schema import (
    OutfitGenerateRequest,
    OutfitGenerateResponse,
)
from .service import OutfitService

router = APIRouter(
    prefix="/profiles/{profile_id}/outfits",
    tags=["Outfits"],
)

service = OutfitService()


@router.post(
    "/generate",
    response_model=OutfitGenerateResponse,
)
def generate_outfits(
    payload: OutfitGenerateRequest,
    owned_profile: Profile = Depends(get_owned_profile),  # noqa: B008
    session: Session = Depends(get_session),  # noqa: B008
) -> OutfitGenerateResponse:
    return service.generate(
        session=session,
        profile=owned_profile,
        payload=payload,
    )

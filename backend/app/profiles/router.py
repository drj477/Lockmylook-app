from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlmodel import Session

from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.core.schema import Envelope
from app.database.session import get_session
from app.profiles import service
from app.profiles.image_service import profile_image_service
from app.profiles.schema import ProfileCreateRequest, ProfileRead

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.post("", response_model=Envelope[ProfileRead], status_code=201)
async def create_profile(
    request: ProfileCreateRequest,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[ProfileRead]:
    profile = service.create_profile(session, current_account.id, request)
    return Envelope(
        message="Profile created successfully.",
        data=ProfileRead.model_validate(profile),
    )


@router.get("", response_model=Envelope[list[ProfileRead]])
async def list_profiles(
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[list[ProfileRead]]:
    profiles = service.list_profiles(session, current_account.id)
    return Envelope(
        message="Profiles retrieved successfully.",
        data=[ProfileRead.model_validate(p) for p in profiles],
    )


@router.get("/{profile_id}", response_model=Envelope[ProfileRead])
async def get_profile(
    profile_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[ProfileRead]:
    profile = service.get_owned_profile(session, current_account.id, profile_id)
    return Envelope(message="Profile retrieved successfully.", data=ProfileRead.model_validate(profile))


@router.post(
    "/{profile_id}/try-on-photo",
    response_model=Envelope[ProfileRead],
    status_code=status.HTTP_200_OK,
)
async def upload_try_on_photo(
    profile_id: UUID,
    file: UploadFile = File(...),
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[ProfileRead]:
    profile = service.get_owned_profile(session, current_account.id, profile_id)

    try:
        profile = profile_image_service.upload(session, profile, file)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

    return Envelope(
        message="Try-On photo saved successfully.",
        data=ProfileRead.model_validate(profile),
    )


@router.delete("/{profile_id}", status_code=204)
async def delete_profile(
    profile_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> None:
    service.delete_profile(session, current_account.id, profile_id)

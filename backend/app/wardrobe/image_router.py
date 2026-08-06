from uuid import UUID

from fastapi import APIRouter, Depends, File, UploadFile, status
from sqlmodel import Session

from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.core.schema import Envelope
from app.database.session import get_session
from app.profiles.service import get_owned_profile
from app.wardrobe.image_schema import ImageRead
from app.wardrobe.image_service import ImageService

router = APIRouter(
    prefix="/profiles/{profile_id}/wardrobe/{item_id}/images",
    tags=["Wardrobe Images"],
)

service = ImageService()


@router.post(
    "",
    response_model=Envelope[ImageRead],
    status_code=status.HTTP_201_CREATED,
)
async def upload_image(
    profile_id: UUID,
    item_id: UUID,
    file: UploadFile = File(...),
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[ImageRead]:

    profile = get_owned_profile(
        session=session,
        account_id=current_account.id,
        profile_id=profile_id,
    )

    image = service.upload(
        session=session,
        item_id=item_id,
        file=file,
    )

    return Envelope(
        message="Image uploaded successfully.",
        data=ImageRead.model_validate(image),
    )


@router.get(
    "",
    response_model=Envelope[list[ImageRead]],
)
async def list_images(
    profile_id: UUID,
    item_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[list[ImageRead]]:

    get_owned_profile(
        session=session,
        account_id=current_account.id,
        profile_id=profile_id,
    )

    images = service.list(
        session=session,
        item_id=item_id,
    )

    return Envelope(
        message="Images retrieved successfully.",
        data=[
            ImageRead.model_validate(image)
            for image in images
        ],
    )


@router.delete(
    "/{image_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_image(
    profile_id: UUID,
    item_id: UUID,
    image_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> None:

    get_owned_profile(
        session=session,
        account_id=current_account.id,
        profile_id=profile_id,
    )

    service.delete(
        session=session,
        image_id=image_id,
    )
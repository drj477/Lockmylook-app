from pathlib import Path
from uuid import UUID

from sqlmodel import Session, select

from app.core.exceptions import NotFoundError
from app.core.logging import log_profile_created
from app.profiles.image_service import profile_image_service
from app.profiles.model import Profile
from app.profiles.schema import ProfileCreateRequest
from app.virtual_try_on.model import VirtualTryOnResult
from app.wardrobe.model import WardrobeImage, WardrobeItem


def create_profile(session: Session, account_id: UUID, request: ProfileCreateRequest) -> Profile:
    profile = Profile(account_id=account_id, name=request.name, avatar_url=request.avatar_url)
    session.add(profile)
    session.commit()
    session.refresh(profile)

    log_profile_created(str(profile.id), str(account_id))
    return profile


def list_profiles(session: Session, account_id: UUID) -> list[Profile]:
    return list(session.exec(select(Profile).where(Profile.account_id == account_id)))


def get_owned_profile(session: Session, account_id: UUID, profile_id: UUID) -> Profile:
    """Return a profile only when it belongs to the authenticated account."""
    profile = session.get(Profile, profile_id)
    if not profile or profile.account_id != account_id:
        raise NotFoundError("Profile not found.")
    return profile


def delete_profile(session: Session, account_id: UUID, profile_id: UUID) -> None:
    profile = get_owned_profile(session, account_id, profile_id)

    # SQLModel's relationships do not currently declare database-level
    # ON DELETE CASCADE, so remove dependent rows explicitly before deleting
    # the profile. This also cleans up all generated/uploaded files.
    wardrobe_items = list(
        session.exec(
            select(WardrobeItem).where(WardrobeItem.profile_id == profile.id)
        )
    )

    for item in wardrobe_items:
        images = list(
            session.exec(
                select(WardrobeImage).where(WardrobeImage.wardrobe_item_id == item.id)
            )
        )
        for image in images:
            _delete_upload_file(image.image_url)
            session.delete(image)
        session.delete(item)

    try_on_results = list(
        session.exec(
            select(VirtualTryOnResult).where(
                VirtualTryOnResult.profile_id == profile.id
            )
        )
    )
    for result in try_on_results:
        _delete_upload_file(result.image_url)
        session.delete(result)

    for path in profile_image_service.stored_paths(profile):
        path.unlink(missing_ok=True)

    session.delete(profile)
    session.commit()


def _delete_upload_file(value: str | None) -> None:
    if not value:
        return

    path = Path(value)
    if not path.is_absolute():
        path = Path.cwd() / path

    path = path.resolve()
    uploads_root = (Path.cwd() / "uploads").resolve()
    try:
        path.relative_to(uploads_root)
    except ValueError:
        return

    path.unlink(missing_ok=True)

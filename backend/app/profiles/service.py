from uuid import UUID

from sqlmodel import Session, select

from app.core.exceptions import NotFoundError
from app.core.logging import log_profile_created
from app.profiles.image_service import profile_image_service
from app.profiles.model import Profile
from app.profiles.schema import ProfileCreateRequest


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
    """The single security-critical function in this feature: an account
    may only ever read/mutate its own profiles. Returns NotFoundError (404)
    rather than ForbiddenError (403) so we don't confirm that a profile_id
    belonging to someone else actually exists.
    """
    profile = session.get(Profile, profile_id)
    if not profile or profile.account_id != account_id:
        raise NotFoundError("Profile not found.")
    return profile


def delete_profile(session: Session, account_id: UUID, profile_id: UUID) -> None:
    profile = get_owned_profile(session, account_id, profile_id)

    # Remove both the original profile photo and its private VTO cutout.
    profile_image_service.delete(session, profile)
    session.delete(profile)
    session.commit()

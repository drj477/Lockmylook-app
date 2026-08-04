from uuid import UUID

from fastapi import Depends
from sqlmodel import Session, select

from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.core.exceptions import NotFoundError
from app.database.session import get_session
from app.profiles.model import Profile


def get_owned_profile(
    profile_id: UUID,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Profile:
    """
    Returns a profile only if it belongs to the authenticated account.

    Security:
    - Returns 404 if the profile doesn't exist.
    - Returns 404 if the profile belongs to another account.
    - Never leaks whether another user's profile exists.
    """

    statement = select(Profile).where(
        Profile.id == profile_id,
        Profile.account_id == current_account.id,
    )

    profile = session.exec(statement).first()

    if profile is None:
        raise NotFoundError("Profile not found.")

    return profile
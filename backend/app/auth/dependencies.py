from dataclasses import dataclass

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlmodel import Session, select

from app.auth.model import Account
from app.auth.session_model import AuthSession
from app.core.exceptions import UnauthorizedError
from app.core.security import TokenType, decode_token_claims
from app.database.session import get_session

_bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentAuth:
    account: Account
    auth_session: AuthSession


def get_current_auth(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    session: Session = Depends(get_session),
) -> CurrentAuth:
    """Validate the access JWT and the server-side session it belongs to."""
    if credentials is None:
        raise UnauthorizedError("Authentication required.")

    try:
        claims = decode_token_claims(credentials.credentials, expected_type=TokenType.ACCESS)
    except (JWTError, ValueError) as exc:
        raise UnauthorizedError("Invalid or expired token.") from exc

    auth_session = session.exec(
        select(AuthSession).where(AuthSession.id == claims.session_id)
    ).first()
    if (
        not auth_session
        or auth_session.account_id != claims.account_id
        or auth_session.revoked_at is not None
        or auth_session.expires_at <= __import__("datetime").datetime.now(__import__("datetime").UTC)
    ):
        raise UnauthorizedError("Invalid or expired token.")

    account = session.get(Account, claims.account_id)
    if not account or not account.is_active:
        raise UnauthorizedError("Invalid or expired token.")

    return CurrentAuth(account=account, auth_session=auth_session)


def get_current_account(current_auth: CurrentAuth = Depends(get_current_auth)) -> Account:
    return current_auth.account

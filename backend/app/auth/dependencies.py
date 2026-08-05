from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlmodel import Session

from app.auth.model import Account
from app.core.exceptions import UnauthorizedError
from app.core.security import TokenType, decode_token
from app.database.session import get_session

_bearer_scheme = HTTPBearer(auto_error=False)


def get_current_account(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    session: Session = Depends(get_session),
) -> Account:
    """Dependency used by every protected route. Raises UnauthorizedError
    (-> 401 via the global handler) for any missing/invalid/expired token.
    """
    if credentials is None:
        raise UnauthorizedError("Authentication required.")

    try:
        account_id = decode_token(credentials.credentials, expected_type=TokenType.ACCESS)
    except (JWTError, ValueError) as exc:
        raise UnauthorizedError("Invalid or expired token.") from exc

    account = session.get(Account, account_id)
    if not account or not account.is_active:
        raise UnauthorizedError("Invalid or expired token.")

    return account

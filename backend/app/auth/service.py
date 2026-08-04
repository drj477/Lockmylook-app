from jose import JWTError
from sqlmodel import Session, select

from app.auth.model import Account
from app.auth.schema import LoginRequest, SignupRequest, TokenPair
from app.core.exceptions import ConflictError, UnauthorizedError
from app.core.logging import (
    log_authentication_failed,
    log_user_logged_in,
    log_user_registered,
)
from app.core.security import (
    TokenType,
    create_token,
    decode_token,
    hash_password,
    verify_password,
)


def signup(session: Session, request: SignupRequest) -> Account:
    existing = session.exec(select(Account).where(Account.email == request.email)).first()
    if existing:
        raise ConflictError("An account with this email already exists.")

    account = Account(email=request.email, hashed_password=hash_password(request.password))
    session.add(account)
    session.commit()
    session.refresh(account)

    log_user_registered(str(account.id), account.email)
    return account


def login(session: Session, request: LoginRequest) -> TokenPair:
    account = session.exec(select(Account).where(Account.email == request.email)).first()

    # Same error message whether the email doesn't exist or the password is
    # wrong -- never reveal which one it was.
    if not account or not verify_password(request.password, account.hashed_password):
        log_authentication_failed(request.email, "invalid credentials")
        raise UnauthorizedError("Invalid email or password.")

    if not account.is_active:
        log_authentication_failed(request.email, "account disabled")
        raise UnauthorizedError("Invalid email or password.")

    log_user_logged_in(str(account.id))
    return _issue_token_pair(account)


def refresh(session: Session, refresh_token: str) -> TokenPair:
    try:
        account_id = decode_token(refresh_token, expected_type=TokenType.REFRESH)
    except (JWTError, ValueError) as exc:
        raise UnauthorizedError("Invalid or expired refresh token.") from exc

    account = session.get(Account, account_id)
    if not account or not account.is_active:
        raise UnauthorizedError("Invalid or expired refresh token.")

    return _issue_token_pair(account)


def _issue_token_pair(account: Account) -> TokenPair:
    return TokenPair(
        access_token=create_token(account.id, TokenType.ACCESS),
        refresh_token=create_token(account.id, TokenType.REFRESH),
    )

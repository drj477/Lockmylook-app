from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from uuid import UUID, uuid4

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from jose import JWTError, jwt

from app.core.config import get_settings

_hasher = PasswordHasher()


class TokenType(StrEnum):
    ACCESS = "access"
    REFRESH = "refresh"


@dataclass(frozen=True)
class TokenClaims:
    account_id: UUID
    session_id: UUID
    token_type: TokenType


# ---------------------------------------------------------------------------
# Password hashing
# ---------------------------------------------------------------------------
def hash_password(plain_password: str) -> str:
    return _hasher.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return _hasher.verify(hashed_password, plain_password)
    except VerifyMismatchError:
        return False


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------
def create_token(
    account_id: UUID,
    token_type: TokenType,
    session_id: UUID | None = None,
) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    session_id = session_id or uuid4()

    if token_type == TokenType.ACCESS:
        expires_at = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    else:
        expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    payload = {
        "sub": str(account_id),
        "sid": str(session_id),
        "type": token_type.value,
        "iat": now,
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token_claims(token: str, expected_type: TokenType) -> TokenClaims:
    """Decode a JWT and require a server-issued session identifier."""
    settings = get_settings()
    payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])

    if payload.get("type") != expected_type.value:
        raise JWTError("Unexpected token type.")

    try:
        account_id = UUID(str(payload["sub"]))
        session_id = UUID(str(payload["sid"]))
    except (KeyError, TypeError, ValueError) as exc:
        raise JWTError("Malformed token claims.") from exc

    return TokenClaims(
        account_id=account_id,
        session_id=session_id,
        token_type=expected_type,
    )


def decode_token(token: str, expected_type: TokenType) -> UUID:
    """Backward-compatible helper returning only the account ID."""
    return decode_token_claims(token, expected_type).account_id

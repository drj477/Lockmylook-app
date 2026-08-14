from datetime import UTC, datetime, timedelta
from enum import StrEnum
from uuid import UUID

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from jose import JWTError, jwt

from app.core.config import get_settings

_hasher = PasswordHasher()


class TokenType(StrEnum):
    ACCESS = "access"
    REFRESH = "refresh"


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
def create_token(account_id: UUID, token_type: TokenType) -> str:
    settings = get_settings()
    now = datetime.now(UTC)

    if token_type == TokenType.ACCESS:
        expires_at = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    else:
        expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    payload = {
        "sub": str(account_id),
        "type": token_type.value,
        "iat": now,
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str, expected_type: TokenType) -> UUID:
    """Decode and validate a JWT. Raises jose.JWTError (or ValueError) on any
    problem: expired, bad signature, wrong type, malformed. Callers (the auth
    dependency) are responsible for turning that into an UnauthorizedError.
    """
    settings = get_settings()
    payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])

    if payload.get("type") != expected_type.value:
        raise JWTError("Unexpected token type.")

    return UUID(payload["sub"])

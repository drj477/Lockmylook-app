from datetime import UTC, datetime, timedelta
import hashlib
import hmac
from uuid import UUID, uuid4

from jose import JWTError
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, delete, select

from app.auth.model import Account
from app.auth.schema import LoginRequest, SignupRequest, TokenPair
from app.auth.session_model import AuthSession, AuthThrottle
from app.core.config import get_settings
from app.core.exceptions import ConflictError, TooManyRequestsError, UnauthorizedError
from app.core.logging import (
    log_authentication_failed,
    log_refresh_token_reuse,
    log_user_logged_in,
    log_user_logged_out,
    log_user_registered,
)
from app.core.security import (
    TokenType,
    create_token,
    decode_token_claims,
    hash_password,
    verify_password,
)

_LOGIN_IP_LIMIT = 20
_LOGIN_IP_WINDOW = timedelta(minutes=15)
_LOGIN_ACCOUNT_LIMIT = 10
_LOGIN_ACCOUNT_WINDOW = timedelta(minutes=15)
_LOGIN_ACCOUNT_BLOCK = timedelta(minutes=2)
_SIGNUP_IP_LIMIT = 5
_SIGNUP_IP_WINDOW = timedelta(hours=1)


def _key_hash(value: str) -> str:
    secret = get_settings().JWT_SECRET_KEY.encode("utf-8")
    return hmac.new(secret, value.encode("utf-8"), hashlib.sha256).hexdigest()


def _ip_hash(ip_address: str | None) -> str | None:
    if not ip_address:
        return None
    return _key_hash(f"ip:{ip_address}")


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _get_or_create_throttle(
    session: Session, scope: str, key_hash: str
) -> AuthThrottle:
    bucket = session.exec(
        select(AuthThrottle)
        .where(AuthThrottle.scope == scope, AuthThrottle.key_hash == key_hash)
        .with_for_update()
    ).first()
    if bucket:
        return bucket

    bucket = AuthThrottle(scope=scope, key_hash=key_hash)
    session.add(bucket)
    try:
        session.flush()
    except IntegrityError:
        session.rollback()
        bucket = session.exec(
            select(AuthThrottle)
            .where(AuthThrottle.scope == scope, AuthThrottle.key_hash == key_hash)
            .with_for_update()
        ).first()
        if bucket is None:
            raise
    return bucket


def _consume_rate_limit(
    session: Session,
    *,
    scope: str,
    key: str,
    limit: int,
    window: timedelta,
) -> None:
    now = datetime.now(UTC)
    bucket = _get_or_create_throttle(session, scope, _key_hash(key))

    if now - bucket.window_started_at >= window:
        bucket.window_started_at = now
        bucket.attempts = 0
        bucket.blocked_until = None

    if bucket.blocked_until and bucket.blocked_until > now:
        raise TooManyRequestsError()

    bucket.attempts += 1
    bucket.last_attempt_at = now

    if bucket.attempts > limit:
        bucket.blocked_until = now + window
        session.commit()
        raise TooManyRequestsError()

    session.commit()


def _check_account_throttle(session: Session, account_id: UUID) -> None:
    now = datetime.now(UTC)
    bucket = session.exec(
        select(AuthThrottle).where(
            AuthThrottle.scope == "login_account",
            AuthThrottle.key_hash == _key_hash(f"account:{account_id}"),
        )
    ).first()
    if not bucket:
        return

    if now - bucket.window_started_at >= _LOGIN_ACCOUNT_WINDOW:
        bucket.attempts = 0
        bucket.window_started_at = now
        bucket.blocked_until = None
        session.commit()
        return

    if bucket.blocked_until and bucket.blocked_until > now:
        raise TooManyRequestsError()


def _record_failed_login(session: Session, account_id: UUID) -> None:
    now = datetime.now(UTC)
    bucket = _get_or_create_throttle(session, "login_account", _key_hash(f"account:{account_id}"))

    if now - bucket.window_started_at >= _LOGIN_ACCOUNT_WINDOW:
        bucket.window_started_at = now
        bucket.attempts = 0
        bucket.blocked_until = None

    bucket.attempts += 1
    bucket.last_attempt_at = now
    if bucket.attempts >= _LOGIN_ACCOUNT_LIMIT:
        bucket.blocked_until = now + _LOGIN_ACCOUNT_BLOCK
    session.commit()


def _clear_failed_login(session: Session, account_id: UUID) -> None:
    session.exec(
        delete(AuthThrottle).where(
            AuthThrottle.scope == "login_account",
            AuthThrottle.key_hash == _key_hash(f"account:{account_id}"),
        )
    )
    session.flush()


def signup(
    session: Session,
    request: SignupRequest,
    *,
    ip_address: str | None = None,
) -> Account:
    if ip_address:
        _consume_rate_limit(
            session,
            scope="signup_ip",
            key=ip_address,
            limit=_SIGNUP_IP_LIMIT,
            window=_SIGNUP_IP_WINDOW,
        )

    email = str(request.email).strip().lower()
    existing = session.exec(select(Account).where(Account.email == email)).first()
    if existing:
        raise ConflictError("An account with this email already exists.")

    account = Account(email=email, hashed_password=hash_password(request.password))
    session.add(account)
    session.commit()
    session.refresh(account)
    log_user_registered(str(account.id))
    return account


def login(
    session: Session,
    request: LoginRequest,
    *,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> TokenPair:
    if ip_address:
        _consume_rate_limit(
            session,
            scope="login_ip",
            key=ip_address,
            limit=_LOGIN_IP_LIMIT,
            window=_LOGIN_IP_WINDOW,
        )

    email = str(request.email).strip().lower()
    account = session.exec(select(Account).where(Account.email == email)).first()

    if account:
        _check_account_throttle(session, account.id)

    password_ok = bool(account and verify_password(request.password, account.hashed_password))
    if not account or not password_ok or not account.is_active:
        if account:
            _record_failed_login(session, account.id)
        log_authentication_failed("invalid credentials")
        raise UnauthorizedError("Invalid email or password.")

    _clear_failed_login(session, account.id)
    tokens = _issue_token_pair(
        session,
        account,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    log_user_logged_in(str(account.id))
    return tokens


def refresh(session: Session, refresh_token: str) -> TokenPair:
    try:
        claims = decode_token_claims(refresh_token, expected_type=TokenType.REFRESH)
    except (JWTError, ValueError) as exc:
        raise UnauthorizedError("Invalid or expired refresh token.") from exc

    auth_session = session.exec(
        select(AuthSession)
        .where(AuthSession.id == claims.session_id)
        .with_for_update()
    ).first()
    now = datetime.now(UTC)

    if not auth_session:
        raise UnauthorizedError("Invalid or expired refresh token.")

    if not hmac.compare_digest(auth_session.refresh_token_hash, _token_hash(refresh_token)):
        sessions = session.exec(
            select(AuthSession)
            .where(AuthSession.account_id == auth_session.account_id)
            .with_for_update()
        ).all()
        for item in sessions:
            if item.revoked_at is None:
                item.revoked_at = now
        session.commit()
        log_refresh_token_reuse(str(auth_session.account_id))
        raise UnauthorizedError("Invalid or expired refresh token.")

    if auth_session.revoked_at or auth_session.expires_at <= now:
        raise UnauthorizedError("Invalid or expired refresh token.")

    account = session.get(Account, auth_session.account_id)
    if not account or not account.is_active:
        auth_session.revoked_at = now
        session.commit()
        raise UnauthorizedError("Invalid or expired refresh token.")

    new_refresh = create_token(account.id, TokenType.REFRESH, auth_session.id)
    new_access = create_token(account.id, TokenType.ACCESS, auth_session.id)
    auth_session.refresh_token_hash = _token_hash(new_refresh)
    auth_session.last_used_at = now
    session.commit()

    return TokenPair(access_token=new_access, refresh_token=new_refresh)


def revoke_session(session: Session, account_id: UUID, session_id: UUID) -> None:
    auth_session = session.exec(
        select(AuthSession)
        .where(AuthSession.id == session_id, AuthSession.account_id == account_id)
        .with_for_update()
    ).first()
    if auth_session and auth_session.revoked_at is None:
        auth_session.revoked_at = datetime.now(UTC)
        session.commit()

    log_user_logged_out(str(account_id))


def revoke_all_sessions(session: Session, account_id: UUID) -> None:
    now = datetime.now(UTC)
    sessions = session.exec(
        select(AuthSession).where(AuthSession.account_id == account_id).with_for_update()
    ).all()
    for auth_session in sessions:
        if auth_session.revoked_at is None:
            auth_session.revoked_at = now
    session.commit()
    log_user_logged_out(str(account_id))


def _issue_token_pair(
    session: Session,
    account: Account,
    *,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> TokenPair:
    now = datetime.now(UTC)
    session_id = uuid4()
    refresh_token = create_token(account.id, TokenType.REFRESH, session_id)
    access_token = create_token(account.id, TokenType.ACCESS, session_id)

    auth_session = AuthSession(
        id=session_id,
        account_id=account.id,
        refresh_token_hash=_token_hash(refresh_token),
        created_at=now,
        expires_at=now + timedelta(days=get_settings().REFRESH_TOKEN_EXPIRE_DAYS),
        last_used_at=now,
        ip_hash=_ip_hash(ip_address),
        user_agent=(user_agent or "")[:512] or None,
    )
    session.add(auth_session)
    session.commit()

    return TokenPair(access_token=access_token, refresh_token=refresh_token)

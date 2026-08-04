from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.auth import service
from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.auth.schema import (
    AccountRead,
    LoginRequest,
    RefreshRequest,
    SignupRequest,
    TokenPair,
)
from app.core.logging import log_user_logged_out
from app.core.schema import Envelope
from app.database.session import get_session

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=Envelope[AccountRead], status_code=201)
async def signup(
    request: SignupRequest, session: Session = Depends(get_session)
) -> Envelope[AccountRead]:
    account = service.signup(session, request)
    return Envelope(
        message="Account created successfully.",
        data=AccountRead.model_validate(account),
    )


@router.post("/login", response_model=Envelope[TokenPair])
async def login(
    request: LoginRequest, session: Session = Depends(get_session)
) -> Envelope[TokenPair]:
    tokens = service.login(session, request)
    return Envelope(message="Login successful.", data=tokens)


@router.post("/refresh", response_model=Envelope[TokenPair])
async def refresh(
    request: RefreshRequest, session: Session = Depends(get_session)
) -> Envelope[TokenPair]:
    tokens = service.refresh(session, request.refresh_token)
    return Envelope(message="Token refreshed successfully.", data=tokens)


@router.post("/logout", status_code=204)
async def logout(current_account: Account = Depends(get_current_account)) -> None:
    # Stateless JWTs: logout is a client-side token discard. We log the
    # event for audit/analytics purposes. If we later need server-side
    # revocation, this is where a token blocklist would be checked/written.
    # (Deferred deliberately -- see docs/Architecture.md "Explicitly deferred".)
    log_user_logged_out(str(current_account.id))

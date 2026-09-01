from fastapi import APIRouter, Depends, Request, Response, status
from sqlmodel import Session

from app.auth import service
from app.auth.dependencies import CurrentAuth, get_current_account, get_current_auth
from app.auth.model import Account
from app.auth.schema import (
    AccountRead,
    LoginRequest,
    RefreshRequest,
    SignupRequest,
    TokenPair,
)
from app.core.schema import Envelope
from app.database.session import get_session

router = APIRouter(prefix="/auth", tags=["auth"])


def _client_ip(request: Request) -> str | None:
    # Do not trust user-controlled X-Forwarded-For here. A trusted reverse
    # proxy can be configured separately when production infrastructure is
    # deployed.
    return request.client.host if request.client else None


@router.post("/signup", response_model=Envelope[AccountRead], status_code=201)
async def signup(
    request: Request,
    payload: SignupRequest,
    session: Session = Depends(get_session),
) -> Envelope[AccountRead]:
    account = service.signup(session, payload, ip_address=_client_ip(request))
    return Envelope(
        message="Account created successfully.",
        data=AccountRead.model_validate(account),
    )


@router.post("/login", response_model=Envelope[TokenPair])
async def login(
    request: Request,
    payload: LoginRequest,
    session: Session = Depends(get_session),
) -> Envelope[TokenPair]:
    tokens = service.login(
        session,
        payload,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
    return Envelope(message="Login successful.", data=tokens)


@router.post("/refresh", response_model=Envelope[TokenPair])
async def refresh(
    request: RefreshRequest, session: Session = Depends(get_session)
) -> Envelope[TokenPair]:
    tokens = service.refresh(session, request.refresh_token)
    return Envelope(message="Token refreshed successfully.", data=tokens)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    current_auth: CurrentAuth = Depends(get_current_auth),
    session: Session = Depends(get_session),
) -> Response:
    service.revoke_session(
        session,
        current_auth.account.id,
        current_auth.auth_session.id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT)
async def logout_all(
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Response:
    service.revoke_all_sessions(session, current_account.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

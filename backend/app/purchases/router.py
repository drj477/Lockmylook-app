from fastapi import APIRouter, Depends, status
from sqlmodel import Session

from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.core.schema import Envelope
from app.database.session import get_session

from .schema import PurchaseCreateRequest, PurchaseResponse
from .service import create_pending_purchase

router = APIRouter(prefix="/credits/purchases", tags=["Credit Purchases"])


@router.post("", response_model=Envelope[PurchaseResponse], status_code=status.HTTP_201_CREATED)
def create_purchase(
    request: PurchaseCreateRequest,
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Envelope[PurchaseResponse]:
    purchase = create_pending_purchase(session, current_account, request)
    return Envelope(
        message="Credit purchase created.",
        data=PurchaseResponse.model_validate(purchase),
    )

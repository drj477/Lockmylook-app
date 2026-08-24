from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.auth.dependencies import get_current_account
from app.auth.model import Account
from app.database.session import get_session

from .model import CreditTransaction
from .schema import CreditBalanceResponse, CreditTransactionResponse
from .service import CREDIT_RUPEES, UNITS_PER_CREDIT

router = APIRouter(prefix="/credits", tags=["Credits"])


@router.get("/balance", response_model=CreditBalanceResponse)
def get_balance(
    current_account: Account = Depends(get_current_account),
) -> CreditBalanceResponse:
    return CreditBalanceResponse(
        balance_credits=current_account.credit_units / UNITS_PER_CREDIT,
        balance_rupees=current_account.credit_units / UNITS_PER_CREDIT * CREDIT_RUPEES,
    )


@router.get("/transactions", response_model=list[CreditTransactionResponse])
def get_transactions(
    current_account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> list[CreditTransaction]:
    return session.exec(
        select(CreditTransaction)
        .where(CreditTransaction.account_id == current_account.id)
        .order_by(CreditTransaction.created_at.desc())
        .limit(100)
    ).all()

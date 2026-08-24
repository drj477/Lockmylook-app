from __future__ import annotations

from uuid import UUID

from sqlmodel import Session, select

from app.auth.model import Account
from app.core.exceptions import AppError

from .model import CreditTransaction, CreditTransactionType

# Public pricing contract. 1 credit = ₹5. Internally 2 units = 1 credit.
CREDIT_RUPEES = 5
UNITS_PER_CREDIT = 2

# Costs in half-credit units.
PAID_GENERATION_UNITS = 4       # 2 credits = ₹10
GEMINI_CHAT_UNITS = 2           # 1 credit = ₹5
CACHE_HIT_UNITS = 1              # 0.5 credit = ₹2.50


class InsufficientCreditsError(AppError):
    status_code = 402
    message = "Not enough credits for this generation."


def generation_cost_units(model: str, cache_hit: bool) -> int:
    if cache_hit:
        return CACHE_HIT_UNITS
    if model == "gemini_chat":
        return GEMINI_CHAT_UNITS
    return PAID_GENERATION_UNITS


def get_balance_units(session: Session, account_id: UUID) -> int:
    account = session.get(Account, account_id)
    if account is None:
        raise ValueError("Account not found.")
    return account.credit_units


def debit(
    session: Session,
    *,
    account_id: UUID,
    units: int,
    transaction_type: CreditTransactionType,
    reason: str,
    provider: str | None = None,
    vto_result_id: UUID | None = None,
) -> CreditTransaction:
    if units <= 0:
        raise ValueError("Credit debit must be positive.")

    # Row-level lock makes concurrent generation requests safe for the same
    # account. We never allow the balance to go negative.
    account = session.exec(
        select(Account)
        .where(Account.id == account_id)
        .with_for_update()
    ).one_or_none()
    if account is None:
        raise ValueError("Account not found.")

    if account.credit_units < units:
        raise InsufficientCreditsError(
            f"Not enough credits. This action requires {units / UNITS_PER_CREDIT:g} "
            f"credits ({units} half-credit units)."
        )

    account.credit_units -= units
    transaction = CreditTransaction(
        account_id=account.id,
        units_delta=-units,
        balance_after_units=account.credit_units,
        transaction_type=transaction_type.value,
        reason=reason,
        provider=provider,
        vto_result_id=vto_result_id,
    )
    session.add(account)
    session.add(transaction)
    session.commit()
    session.refresh(transaction)
    return transaction


def credit(
    session: Session,
    *,
    account_id: UUID,
    units: int,
    transaction_type: CreditTransactionType,
    reason: str,
    provider: str | None = None,
    vto_result_id: UUID | None = None,
) -> CreditTransaction:
    if units <= 0:
        raise ValueError("Credit amount must be positive.")

    account = session.exec(
        select(Account)
        .where(Account.id == account_id)
        .with_for_update()
    ).one_or_none()
    if account is None:
        raise ValueError("Account not found.")

    account.credit_units += units
    transaction = CreditTransaction(
        account_id=account.id,
        units_delta=units,
        balance_after_units=account.credit_units,
        transaction_type=transaction_type.value,
        reason=reason,
        provider=provider,
        vto_result_id=vto_result_id,
    )
    session.add(account)
    session.add(transaction)
    session.commit()
    session.refresh(transaction)
    return transaction


def refund_generation(
    session: Session,
    *,
    account_id: UUID,
    units: int,
    provider: str | None,
) -> CreditTransaction:
    return credit(
        session,
        account_id=account_id,
        units=units,
        transaction_type=CreditTransactionType.REFUND,
        reason="Failed virtual try-on generation",
        provider=provider,
    )

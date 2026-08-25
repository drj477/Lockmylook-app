from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError

from app.auth.model import Account
from app.core.exceptions import ConflictError, ValidationFailedError

from .catalog import get_credit_package
from .model import CreditPurchase
from .schema import PurchaseCreateRequest


def create_pending_purchase(
    session: Session,
    account: Account,
    request: PurchaseCreateRequest,
) -> CreditPurchase:
    package = get_credit_package(request.package_code)
    if package is None:
        raise ValidationFailedError("Invalid credit package.")

    existing = session.exec(
        select(CreditPurchase).where(
            CreditPurchase.account_id == account.id,
            CreditPurchase.idempotency_key == request.idempotency_key,
        )
    ).first()
    if existing is not None:
        if existing.package_code != package.code:
            raise ConflictError(
                "Idempotency key was already used for a different package."
            )
        return existing

    purchase = CreditPurchase(
        account_id=account.id,
        package_code=package.code,
        credits=package.credits,
        amount_paise=package.amount_paise,
        currency="INR",
    )
    purchase.idempotency_key = request.idempotency_key

    session.add(purchase)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        existing = session.exec(
            select(CreditPurchase).where(
                CreditPurchase.account_id == account.id,
                CreditPurchase.idempotency_key == request.idempotency_key,
            )
        ).first()
        if existing is None:
            raise
        if existing.package_code != package.code:
            raise ConflictError(
                "Idempotency key was already used for a different package."
            )
        return existing

    session.refresh(purchase)
    return purchase

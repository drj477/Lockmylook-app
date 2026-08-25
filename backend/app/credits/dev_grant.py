"""Development-only CLI for granting test credits.

This module is intentionally not exposed through the HTTP API. It exists so
local development can seed an account through the same credit ledger used by
production flows, without manually editing PostgreSQL.
"""

from __future__ import annotations

import argparse
import sys

from sqlmodel import Session, select

from app.auth.model import Account
from app.core.config import get_settings
from app.credits.model import CreditTransactionType
from app.credits.service import UNITS_PER_CREDIT, credit
from app.database.session import engine


def grant(email: str, credits: float) -> None:
    settings = get_settings()
    if settings.ENVIRONMENT.lower() not in {"development", "test"}:
        raise RuntimeError(
            "Development credit grants are disabled outside development/test "
            "environments."
        )

    if credits <= 0:
        raise ValueError("Credits must be greater than zero.")

    units = int(credits * UNITS_PER_CREDIT)
    if units <= 0 or units != credits * UNITS_PER_CREDIT:
        raise ValueError("Credits must be in 0.5-credit increments.")

    with Session(engine) as session:
        account = session.exec(
            select(Account).where(Account.email == email.strip().lower())
        ).one_or_none()
        if account is None:
            raise ValueError(f"Account not found: {email}")

        transaction = credit(
            session,
            account_id=account.id,
            units=units,
            transaction_type=CreditTransactionType.ADJUSTMENT,
            reason="Development credit grant",
        )

        print(
            f"Granted {credits:g} credits (₹{credits * 5:g}) to {account.email}. "
            f"Balance: {transaction.balance_after_units / UNITS_PER_CREDIT:g} credits."
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Grant development credits through the LockMyLook ledger."
    )
    parser.add_argument("email", help="Account email")
    parser.add_argument("credits", type=float, help="Credits to grant (0.5 increments)")
    args = parser.parse_args()

    try:
        grant(args.email, args.credits)
    except (RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

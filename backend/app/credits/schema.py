from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class CreditBalanceResponse(BaseModel):
    balance_credits: float
    balance_rupees: float


class CreditTransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    units_delta: int
    balance_after_units: int
    transaction_type: str
    reason: str
    provider: str | None
    vto_result_id: UUID | None
    created_at: datetime

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PurchaseCreateRequest(BaseModel):
    package_code: str = Field(min_length=1, max_length=64)
    idempotency_key: str = Field(min_length=1, max_length=128)


class PurchaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    package_code: str
    credits: int
    amount_paise: int
    currency: str
    status: str
    payment_provider: str | None
    provider_order_id: str | None
    created_at: datetime

from uuid import UUID

from pydantic import BaseModel, EmailStr, field_validator

from app.core.validators import validate_password_strength


class SignupRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        return validate_password_strength(value)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccountRead(BaseModel):
    id: UUID
    email: EmailStr

    model_config = {"from_attributes": True}

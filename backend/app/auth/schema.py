from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator

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
    password: str = Field(max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=4096)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccountRead(BaseModel):
    id: UUID
    email: EmailStr

    model_config = {"from_attributes": True}

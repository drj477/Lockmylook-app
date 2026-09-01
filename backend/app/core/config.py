from functools import lru_cache
import hashlib

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


_DEFAULT_DATABASE_URL = "postgresql+psycopg://lockmylook:lockmylook_dev@localhost:5432/lockmylook"
_INSECURE_JWT_SECRET_SHA256 = "f0e3c18d1c64651b40d1b792ce20e5684d37493f6e8675117b5c9f502ad63c13"


class Settings(BaseSettings):
    """Application configuration loaded from environment / local .env.

    Security-sensitive JWT configuration has no insecure default. Production
    also rejects the development database fallback.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    APP_NAME: str = "LockMyLook"
    ENVIRONMENT: str = "development"
    API_V1_PREFIX: str = "/api/v1"

    # Database. Kept for local development compatibility; production rejects it.
    DATABASE_URL: str = _DEFAULT_DATABASE_URL

    # JWT
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Virtual Try-On
    REPLICATE_API_TOKEN: str = ""
    PRUNA_API_KEY: str = ""
    PRUNA_PUBLIC_BASE_URL: str = ""
    GEMINI_API_KEY: str = ""
    GEMINI_IMAGE_MODEL: str = "gemini-3.1-flash-image"
    GEMINI_IMAGE_SIZE: str = "2K"

    # Experimental Gemini Chat provider. Credentials stay server-side.
    GEMINI_CHAT_COOKIE_JSON: str = ""
    GEMINI_CHAT_COOKIE_CACHE_DIR: str = "secrets/gemini_webapi"
    GEMINI_CHAT_TIMEOUT_SECONDS: float = 450

    # Logging
    LOG_LEVEL: str = "INFO"

    @model_validator(mode="after")
    def validate_security_configuration(self) -> "Settings":
        if self.JWT_ALGORITHM != "HS256":
            raise ValueError("JWT_ALGORITHM must remain HS256 for the current symmetric-key design.")

        secret_hash = hashlib.sha256(self.JWT_SECRET_KEY.encode("utf-8")).hexdigest()
        if secret_hash == _INSECURE_JWT_SECRET_SHA256:
            raise ValueError("JWT_SECRET_KEY is still using an insecure development secret.")

        if len(self.JWT_SECRET_KEY) < 43:
            raise ValueError(
                "JWT_SECRET_KEY must be at least 43 characters of cryptographically random data."
            )

        if self.ACCESS_TOKEN_EXPIRE_MINUTES <= 0 or self.ACCESS_TOKEN_EXPIRE_MINUTES > 60:
            raise ValueError("ACCESS_TOKEN_EXPIRE_MINUTES must be between 1 and 60.")

        if self.REFRESH_TOKEN_EXPIRE_DAYS <= 0 or self.REFRESH_TOKEN_EXPIRE_DAYS > 30:
            raise ValueError("REFRESH_TOKEN_EXPIRE_DAYS must be between 1 and 30.")

        if self.ENVIRONMENT.lower() in {"production", "prod"}:
            if not self.DATABASE_URL:
                raise ValueError("DATABASE_URL is required in production.")
            if self.DATABASE_URL == _DEFAULT_DATABASE_URL:
                raise ValueError("Production cannot use the development database URL.")

        return self


@lru_cache
def get_settings() -> Settings:
    """Cached so we don't re-parse the environment on every request."""
    return Settings()

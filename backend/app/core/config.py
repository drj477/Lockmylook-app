from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration. Values come from environment variables /
    a local .env file. Never hardcode secrets anywhere else in the codebase.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    APP_NAME: str = "LockMyLook"
    ENVIRONMENT: str = "development"
    API_V1_PREFIX: str = "/api/v1"

    # Database
    DATABASE_URL: str = (
        "postgresql+psycopg://lockmylook:lockmylook_dev@localhost:5432/lockmylook"
    )

    # JWT
    JWT_SECRET_KEY: str = "change-me-in-.env-this-is-not-a-real-secret"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Virtual Try-On
    REPLICATE_API_TOKEN: str = ""

    # Logging
    LOG_LEVEL: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    """Cached so we don't re-parse the environment on every request."""
    return Settings()

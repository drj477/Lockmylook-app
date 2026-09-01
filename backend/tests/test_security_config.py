import pytest

from app.core.config import Settings


def test_jwt_secret_must_not_use_old_default():
    with pytest.raises(ValueError, match="insecure development default"):
        Settings(JWT_SECRET_KEY="change-me-in-.env-this-is-not-a-real-secret")


def test_jwt_secret_must_be_strong():
    with pytest.raises(ValueError, match="at least 43 characters"):
        Settings(JWT_SECRET_KEY="too-short")


def test_production_requires_database_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(ValueError, match="DATABASE_URL is required in production"):
        Settings(
            JWT_SECRET_KEY="A" * 64,
            ENVIRONMENT="production",
            DATABASE_URL="",
        )


def test_valid_test_configuration_is_accepted():
    settings = Settings(
        JWT_SECRET_KEY="A" * 64,
        ENVIRONMENT="test",
        DATABASE_URL="sqlite://",
    )
    assert settings.JWT_ALGORITHM == "HS256"
    assert settings.ACCESS_TOKEN_EXPIRE_MINUTES == 30
    assert settings.REFRESH_TOKEN_EXPIRE_DAYS == 30

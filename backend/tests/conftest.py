import os
import secrets

# Tests need a strong ephemeral secret because production configuration no
# longer provides an insecure JWT fallback.
os.environ.setdefault("JWT_SECRET_KEY", secrets.token_urlsafe(32))
os.environ.setdefault("ENVIRONMENT", "test")

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

from app.auth.model import Account  # noqa: F401
from app.auth.session_model import AuthSession, AuthThrottle  # noqa: F401
from app.database import session as db_session
from app.database.session import get_session
from app.main import app
from app.profiles.model import Profile  # noqa: F401
from app.purchases.model import CreditPurchase  # noqa: F401


@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


@pytest.fixture(name="client")
def client_fixture(session: Session, monkeypatch: pytest.MonkeyPatch):
    def get_session_override():
        return session

    app.dependency_overrides[get_session] = get_session_override
    monkeypatch.setattr(db_session, "engine", session.get_bind())

    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


@pytest.fixture
def registered_account(client: TestClient) -> dict:
    payload = {"email": "user@example.com", "password": "password123"}
    response = client.post("/api/v1/auth/signup", json=payload)
    assert response.status_code == 201
    return payload


@pytest.fixture
def auth_headers(client: TestClient, registered_account: dict) -> dict:
    response = client.post("/api/v1/auth/login", json=registered_account)
    token = response.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

# Import models so their tables register on SQLModel.metadata before create_all
from app.auth.model import Account  # noqa: F401
from app.database import session as db_session
from app.database.session import get_session
from app.main import app
from app.profiles.model import Profile  # noqa: F401


@pytest.fixture(name="session")
def session_fixture():
    # In-memory SQLite keeps the auth/profile test suite fast and hermetic.
    # It's a deliberate trade-off: these tests exercise our business logic,
    # not Postgres-specific behavior. Anything relying on Postgres-only
    # features should instead run against the Dockerized Postgres.
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

    # The app's startup lifespan does a real "SELECT 1" against
    # app.database.session.engine to fail fast if the DB is unreachable.
    # Point it at the same in-memory engine the tests use, so TestClient's
    # startup event doesn't try to reach a real (absent) Postgres instance.
    monkeypatch.setattr(db_session, "engine", session.get_bind())

    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


@pytest.fixture
def registered_account(client: TestClient) -> dict:
    """Signs up a user and returns email/password for reuse in login tests."""
    payload = {"email": "user@example.com", "password": "password123"}
    response = client.post("/api/v1/auth/signup", json=payload)
    assert response.status_code == 201
    return payload


@pytest.fixture
def auth_headers(client: TestClient, registered_account: dict) -> dict:
    response = client.post("/api/v1/auth/login", json=registered_account)
    token = response.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}

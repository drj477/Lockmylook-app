from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.security import TokenType, create_token


# ---------------------------------------------------------------------------
# Signup
# ---------------------------------------------------------------------------
def test_signup_valid(client: TestClient):
    response = client.post(
        "/api/v1/auth/signup", json={"email": "new@example.com", "password": "password123"}
    )
    assert response.status_code == 201
    body = response.json()
    assert body["success"] is True
    assert body["data"]["email"] == "new@example.com"
    assert "id" in body["data"]


def test_signup_duplicate_email_rejected(client: TestClient, registered_account: dict):
    response = client.post("/api/v1/auth/signup", json=registered_account)
    assert response.status_code == 409
    assert response.json()["success"] is False


def test_signup_weak_password_rejected(client: TestClient):
    response = client.post(
        "/api/v1/auth/signup", json={"email": "weak@example.com", "password": "short"}
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------
def test_login_correct_credentials(client: TestClient, registered_account: dict):
    response = client.post("/api/v1/auth/login", json=registered_account)
    assert response.status_code == 200
    body = response.json()["data"]
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"


def test_login_wrong_password(client: TestClient, registered_account: dict):
    response = client.post(
        "/api/v1/auth/login",
        json={"email": registered_account["email"], "password": "wrong-password"},
    )
    assert response.status_code == 401
    assert response.json()["success"] is False


def test_login_unknown_email(client: TestClient):
    response = client.post(
        "/api/v1/auth/login", json={"email": "nobody@example.com", "password": "password123"}
    )
    assert response.status_code == 401


def test_login_wrong_and_unknown_return_identical_message(
    client: TestClient, registered_account: dict
):
    # Never let the error message reveal whether the email exists.
    wrong_password = client.post(
        "/api/v1/auth/login",
        json={"email": registered_account["email"], "password": "wrong-password"},
    )
    unknown_email = client.post(
        "/api/v1/auth/login", json={"email": "nobody@example.com", "password": "password123"}
    )
    assert wrong_password.json()["message"] == unknown_email.json()["message"]


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------
def test_valid_token_grants_access(client: TestClient, auth_headers: dict):
    response = client.get("/api/v1/profiles", headers=auth_headers)
    assert response.status_code == 200


def test_missing_token_rejected(client: TestClient):
    response = client.get("/api/v1/profiles")
    assert response.status_code == 401


def test_invalid_signature_rejected(client: TestClient):
    bad_token = create_token(uuid4(), TokenType.ACCESS) + "tampered"
    response = client.get(
        "/api/v1/profiles", headers={"Authorization": f"Bearer {bad_token}"}
    )
    assert response.status_code == 401


def test_expired_token_rejected(client: TestClient, monkeypatch):
    from datetime import datetime, timedelta, timezone

    from app.core import security

    # Force create_token to mint an already-expired access token.
    def expired_create_token(account_id, token_type):
        now = datetime.now(timezone.utc)
        payload = {
            "sub": str(account_id),
            "type": token_type.value,
            "iat": now - timedelta(minutes=60),
            "exp": now - timedelta(minutes=1),
        }
        from jose import jwt

        from app.core.config import get_settings

        settings = get_settings()
        return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

    monkeypatch.setattr(security, "create_token", expired_create_token)
    expired = security.create_token(uuid4(), TokenType.ACCESS)

    response = client.get("/api/v1/profiles", headers={"Authorization": f"Bearer {expired}"})
    assert response.status_code == 401

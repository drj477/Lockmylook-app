from datetime import UTC
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


def test_signup_rate_limited_by_ip(client: TestClient):
    for index in range(5):
        response = client.post(
            "/api/v1/auth/signup",
            json={"email": f"rate-{index}@example.com", "password": "password123"},
        )
        assert response.status_code == 201

    blocked = client.post(
        "/api/v1/auth/signup",
        json={"email": "rate-blocked@example.com", "password": "password123"},
    )
    assert blocked.status_code == 429
    assert blocked.json()["message"] == "Too many requests. Please try again later."


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
    wrong_password = client.post(
        "/api/v1/auth/login",
        json={"email": registered_account["email"], "password": "wrong-password"},
    )
    unknown_email = client.post(
        "/api/v1/auth/login", json={"email": "nobody@example.com", "password": "password123"}
    )
    assert wrong_password.json()["message"] == unknown_email.json()["message"]


def test_login_ip_rate_limit(client: TestClient):
    for index in range(20):
        response = client.post(
            "/api/v1/auth/login",
            json={"email": f"nobody-{index}@example.com", "password": "password123"},
        )
        assert response.status_code == 401

    blocked = client.post(
        "/api/v1/auth/login",
        json={"email": "another@example.com", "password": "password123"},
    )
    assert blocked.status_code == 429
    assert blocked.json()["message"] == "Too many requests. Please try again later."


def test_login_account_throttling_and_soft_lockout(
    client: TestClient, registered_account: dict, monkeypatch
):
    from app.auth import service

    monkeypatch.setattr(service, "verify_password", lambda *_args, **_kwargs: False)

    for _ in range(10):
        response = client.post("/api/v1/auth/login", json=registered_account)
        assert response.status_code == 401

    blocked = client.post("/api/v1/auth/login", json=registered_account)
    assert blocked.status_code == 429
    assert blocked.json()["message"] == "Too many requests. Please try again later."


# ---------------------------------------------------------------------------
# Sessions / refresh rotation
# ---------------------------------------------------------------------------
def test_refresh_token_rotates_and_old_token_is_invalidated(
    client: TestClient, registered_account: dict
):
    login = client.post("/api/v1/auth/login", json=registered_account)
    first = login.json()["data"]

    rotated = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}
    )
    assert rotated.status_code == 200
    second = rotated.json()["data"]
    assert second["refresh_token"] != first["refresh_token"]
    assert second["access_token"] != first["access_token"]

    replay = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}
    )
    assert replay.status_code == 401

    # Reuse detection revokes the whole authorization, including the newest
    # rotated token that an attacker could otherwise try to keep alive.
    after_reuse = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": second["refresh_token"]}
    )
    assert after_reuse.status_code == 401


def test_logout_revokes_current_session(client: TestClient, registered_account: dict):
    login = client.post("/api/v1/auth/login", json=registered_account)
    tokens = login.json()["data"]
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    logout = client.post("/api/v1/auth/logout", headers=headers)
    assert logout.status_code == 204
    assert logout.content == b""

    protected = client.get("/api/v1/profiles", headers=headers)
    assert protected.status_code == 401

    refresh = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refresh.status_code == 401


def test_logout_all_revokes_all_devices(client: TestClient, registered_account: dict):
    first_login = client.post("/api/v1/auth/login", json=registered_account)
    second_login = client.post("/api/v1/auth/login", json=registered_account)
    first = first_login.json()["data"]
    second = second_login.json()["data"]

    response = client.post(
        "/api/v1/auth/logout-all",
        headers={"Authorization": f"Bearer {first['access_token']}"},
    )
    assert response.status_code == 204

    for token in (first["access_token"], second["access_token"]):
        protected = client.get(
            "/api/v1/profiles", headers={"Authorization": f"Bearer {token}"}
        )
        assert protected.status_code == 401

    for token in (first["refresh_token"], second["refresh_token"]):
        refresh = client.post("/api/v1/auth/refresh", json={"refresh_token": token})
        assert refresh.status_code == 401


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
    from datetime import datetime, timedelta

    from app.core import security

    def expired_create_token(account_id, token_type, session_id=None):
        now = datetime.now(UTC)
        payload = {
            "sub": str(account_id),
            "sid": str(session_id or uuid4()),
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

from fastapi.testclient import TestClient


def _signup_and_login(client: TestClient, email: str, password: str = "password123") -> dict:
    client.post("/api/v1/auth/signup", json={"email": email, "password": password})
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    token = response.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_account_can_create_and_list_own_profile(client: TestClient):
    headers = _signup_and_login(client, "owner@example.com")

    create = client.post("/api/v1/profiles", json={"name": "Me"}, headers=headers)
    assert create.status_code == 201

    listed = client.get("/api/v1/profiles", headers=headers)
    assert listed.status_code == 200
    profiles = listed.json()["data"]
    assert len(profiles) == 1
    assert profiles[0]["name"] == "Me"


def test_account_b_cannot_read_account_a_profile(client: TestClient):
    headers_a = _signup_and_login(client, "account-a@example.com")
    headers_b = _signup_and_login(client, "account-b@example.com")

    created = client.post("/api/v1/profiles", json={"name": "A's Profile"}, headers=headers_a)
    profile_id = created.json()["data"]["id"]

    # Account B must never be able to read Account A's profile.
    response = client.get(f"/api/v1/profiles/{profile_id}", headers=headers_b)
    assert response.status_code == 404  # not 403 -- don't confirm existence


def test_account_b_cannot_delete_account_a_profile(client: TestClient):
    headers_a = _signup_and_login(client, "account-a2@example.com")
    headers_b = _signup_and_login(client, "account-b2@example.com")

    created = client.post("/api/v1/profiles", json={"name": "A's Profile"}, headers=headers_a)
    profile_id = created.json()["data"]["id"]

    delete_attempt = client.delete(f"/api/v1/profiles/{profile_id}", headers=headers_b)
    assert delete_attempt.status_code == 404

    # Confirm it still exists for the rightful owner.
    still_there = client.get(f"/api/v1/profiles/{profile_id}", headers=headers_a)
    assert still_there.status_code == 200


def test_account_cannot_list_another_accounts_profiles(client: TestClient):
    headers_a = _signup_and_login(client, "account-a3@example.com")
    headers_b = _signup_and_login(client, "account-b3@example.com")

    client.post("/api/v1/profiles", json={"name": "A's Profile 1"}, headers=headers_a)
    client.post("/api/v1/profiles", json={"name": "A's Profile 2"}, headers=headers_a)
    client.post("/api/v1/profiles", json={"name": "B's Profile"}, headers=headers_b)

    b_profiles = client.get("/api/v1/profiles", headers=headers_b).json()["data"]
    assert len(b_profiles) == 1
    assert b_profiles[0]["name"] == "B's Profile"

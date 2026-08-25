from fastapi.testclient import TestClient


def test_create_pending_purchase(client: TestClient, auth_headers: dict) -> None:
    response = client.post(
        "/api/v1/credits/purchases",
        headers=auth_headers,
        json={"package_code": "basic", "idempotency_key": "purchase-test-1"},
    )

    assert response.status_code == 201
    data = response.json()["data"]
    assert data["package_code"] == "basic"
    assert data["credits"] == 10
    assert data["amount_paise"] == 5000
    assert data["currency"] == "INR"
    assert data["status"] == "pending"
    assert data["payment_provider"] is None
    assert data["provider_order_id"] is None


def test_invalid_package_is_rejected(client: TestClient, auth_headers: dict) -> None:
    response = client.post(
        "/api/v1/credits/purchases",
        headers=auth_headers,
        json={"package_code": "does-not-exist", "idempotency_key": "purchase-test-2"},
    )

    assert response.status_code == 422
    assert response.json()["success"] is False


def test_same_idempotency_key_returns_same_purchase(
    client: TestClient, auth_headers: dict
) -> None:
    payload = {"package_code": "standard", "idempotency_key": "purchase-test-3"}

    first = client.post(
        "/api/v1/credits/purchases", headers=auth_headers, json=payload
    )
    second = client.post(
        "/api/v1/credits/purchases", headers=auth_headers, json=payload
    )

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["data"]["id"] == second.json()["data"]["id"]
    assert second.json()["data"]["status"] == "pending"


def test_idempotency_key_cannot_be_reused_for_different_package(
    client: TestClient, auth_headers: dict
) -> None:
    key = "purchase-test-4"
    first = client.post(
        "/api/v1/credits/purchases",
        headers=auth_headers,
        json={"package_code": "basic", "idempotency_key": key},
    )
    second = client.post(
        "/api/v1/credits/purchases",
        headers=auth_headers,
        json={"package_code": "pro", "idempotency_key": key},
    )

    assert first.status_code == 201
    assert second.status_code == 409
    assert second.json()["success"] is False

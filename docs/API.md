# API Reference — v0.1 (Sprint 1)

Base URL: `/api/v1`

All responses use the standard envelope:

```json
{ "success": true, "message": "...", "data": {}, "errors": [] }
```

## Health

### `GET /health`
No auth required. Confirms the app is up and the database is reachable.

## Auth

### `POST /auth/signup`
```json
// request
{ "email": "user@example.com", "password": "password123" }
// 201 response (data)
{ "id": "uuid", "email": "user@example.com" }
```
`409` if the email is already registered. `422` if the password fails
strength validation (min 8 chars, at least one letter and one digit).

### `POST /auth/login`
```json
// request
{ "email": "user@example.com", "password": "password123" }
// 200 response (data)
{ "access_token": "...", "refresh_token": "...", "token_type": "bearer" }
```
`401` for wrong password, unknown email, or disabled account — always the
same message, so the API never reveals which case occurred.

### `POST /auth/refresh`
```json
{ "refresh_token": "..." }
```
Returns a new token pair. `401` if the refresh token is invalid, expired,
or of the wrong type.

### `POST /auth/logout`
Requires `Authorization: Bearer <access_token>`. `204` on success. Logout
is a client-side token discard (JWTs are stateless); this endpoint records
the event for logging purposes.

## Profiles

All endpoints require `Authorization: Bearer <access_token>`.

### `POST /profiles`
```json
{ "name": "Wife", "avatar_url": null }
```
`201` with the created profile.

### `GET /profiles`
Returns only the current account's own profiles.

### `GET /profiles/{profile_id}`
`404` if the profile doesn't exist **or** belongs to a different account
(these two cases are indistinguishable by design).

### `DELETE /profiles/{profile_id}`
`204` on success. Same 404-for-not-owned rule as above.

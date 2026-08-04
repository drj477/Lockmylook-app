# Architecture (Frozen)

Locked as of Sprint 1. Not revisited unless implementation surfaces a real
problem — see "Change policy" at the bottom.

## Stack

| Layer | Choice |
|---|---|
| Backend | FastAPI |
| ORM | SQLModel |
| Database | PostgreSQL (Docker for infra only) |
| Migrations | Alembic |
| Auth | JWT (access + refresh) + Argon2 password hashing |
| Validation | Pydantic v2 |
| Logging | Loguru — business events only, not request noise |
| Testing | Pytest (SQLite in-memory for auth/profile suites) |
| Formatting/Lint/Types | Black, isort, Ruff, Pyright — enforced via pre-commit |

## Request flow

```
Router → Service → SQLModel → PostgreSQL
```

- **No repository layer.** SQLModel already abstracts persistence; adding a
  repository on top is unjustified indirection at this scale. Revisit if a
  service needs the same complex query in 3+ places (Rule of Three), or if
  we need to swap persistence backends.
- **Routers are thin.** Parse request → call service → return response.
  No business logic, no validation logic, no direct DB access in a router.
- **Exceptions are centralized.** Services raise `AppError` subclasses
  (`NotFoundError`, `UnauthorizedError`, `ConflictError`, ...). A single
  global handler in `app/core/exceptions.py` converts these into the
  standard response envelope. No route-level try/except.

## ID strategy (mixed, not blanket)

- **Public tables** (`accounts`, `profiles`, and future `wardrobe`,
  `outfits`) use **UUID** primary keys — they're referenced in URLs and
  must not be enumerable.
- **Internal-only tables** (future: AI metadata, embeddings, usage/audit
  data) use **BIGINT** — faster indexing, never exposed externally.

## Cross-cutting concerns

- **Response envelope.** Every response — success or error — has the shape
  `{"success": bool, "message": str, "data": ..., "errors": [...]}`.
  Errors are wrapped globally by the exception handlers. Success responses
  are wrapped explicitly per-route using `app/core/schema.py::Envelope`.
- **Request correlation ID.** `RequestIDMiddleware` (`app/core/middleware.py`)
  reuses an incoming `X-Request-ID` header or generates one, stores it in a
  contextvar, and every log line for that request is tagged with it
  (`app/core/logging.py`). Echoed back in the response header.
- **Fail-fast startup.** The app's `lifespan` handler runs `SELECT 1`
  against the database before accepting traffic; if the DB is unreachable,
  the app refuses to start rather than failing on the first real request.
- **App factory.** `create_app()` in `app/main.py` builds the app rather
  than constructing it at import time, so tests can construct a
  differently-wired app without monkeypatching module globals.

## Security-critical rule: profile ownership

Every protected endpoint that touches a `Profile` must verify
`profile.account_id == current_account.id` before returning or mutating
anything. Violations return **404**, not 403 — a 403 confirms the resource
exists for someone else, which is itself information leakage.

This is implemented once, centrally, in `app/profiles/service.py::get_owned_profile`
and is covered by the mandatory `tests/test_profile_ownership.py` suite.

## Infrastructure boundary

Docker is used **only** for infrastructure (Postgres now; Redis/pgAdmin
later if justified). The application itself runs natively via
`uvicorn --reload`. We containerize the app only at deploy time.

## Explicitly deferred (not "never," just "not yet")

- Repository pattern
- Redis / caching layer
- Celery / background job queue
- S3/R2 storage abstraction (Cloudinary free tier is sufficient)
- Complex permission system (Account → Profile is the only relationship
  we need right now)
- Audit logging beyond business-event logs
- **Refresh-token revocation table.** Proposed in a Sprint 1 review as a
  security improvement (server-side logout / stolen-token invalidation).
  Deliberately deferred: it's a new table plus a lookup on every refresh,
  i.e. real infrastructure, and nothing so far has surfaced a concrete need
  for it. Revisit if there's an actual incident (leaked token, need to
  remotely sign out a device) — not preemptively.

These get reintroduced when real usage data justifies them — not
speculatively.

## Change policy

This document is "frozen": we don't reopen these decisions in ordinary
feature work. A change here requires a concrete problem discovered during
implementation (e.g., a query pattern that's genuinely painful without a
repository, a load pattern that needs caching) — not a hypothetical.

# LockMyLook

A wardrobe & outfit-planning app. Backend: FastAPI + SQLModel + PostgreSQL.

## Architecture (frozen — see `docs/Architecture.md`)

```
Router → Service → SQLModel → PostgreSQL
```

No repository layer, no Redis, no Celery, until real usage data justifies them.

Virtual Try-On keeps the same service boundary while routing generation through a selectable provider (`Replicate` or `Gemini`). Provider-specific API code lives inside the Virtual Try-On service module and does not leak into routers or the mobile client.

## Local setup

1. **Start infrastructure** (Postgres only — the app runs natively):
   ```bash
   docker compose up -d postgres
   ```

2. **Create a virtualenv and install dependencies:**
   ```bash
   cd backend
   python3 -m venv .venv
   source .venv/bin/activate        # Windows: .venv\\Scripts\\activate
   pip install -r requirements.txt
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env
   # edit .env — at minimum set a real JWT_SECRET_KEY
   # set REPLICATE_API_TOKEN for Replicate try-on
   # set GEMINI_API_KEY to enable Gemini try-on
   ```

4. **Run migrations:**
   ```bash
   alembic upgrade head
   ```

5. **Run the app:**
   ```bash
   uvicorn app.main:app --reload
   ```
   API docs: http://localhost:8000/docs
   Health check: http://localhost:8000/api/v1/health

6. **Enable git hooks** (formatting/lint/types on commit, tests on push):
   ```bash
   pre-commit install --hook-type pre-commit --hook-type pre-push
   ```

## Virtual Try-On models

The mobile Virtual Try-On page exposes a model dropdown. The selected value is sent to the backend as `model` and persisted with the generated result.

- **Replicate** — existing `prunaai/p-image-try-on` path; remains the default.
- **Gemini** — Gemini image editing using `gemini-3.1-flash-image` with the person image plus garment reference images.

Gemini's image API supports multi-image composition/editing and configurable image output size. The backend keeps the Gemini API key server-side; the mobile app never receives provider credentials.

## Running tests

```bash
pytest
```

Tests use an in-memory SQLite database and don't require Docker/Postgres to be running.

## Sprint 1 scope

- [x] FastAPI project skeleton, config, logging, global exception handling
- [x] Dockerized PostgreSQL (infra only)
- [x] Health endpoint
- [x] Signup / Login / Refresh / Logout (JWT + Argon2)
- [x] Profile creation, listing, retrieval, deletion (ownership-enforced)
- [x] Auth + profile-ownership test suite
- [ ] Alembic migration applied against a live database (requires running `docker compose up` + `alembic upgrade head` locally — not run in this environment)

See `docs/SprintLog.md` for what's next.

# LockMyLook

A wardrobe & outfit-planning app. Backend: FastAPI + SQLModel + PostgreSQL.

## Architecture (frozen — see `docs/Architecture.md`)

```
Router → Service → SQLModel → PostgreSQL
```

No repository layer, no Redis, no Celery, until real usage data justifies them.

## Local setup

1. **Start infrastructure** (Postgres only — the app runs natively):
   ```bash
   docker compose up -d postgres
   ```

2. **Create a virtualenv and install dependencies:**
   ```bash
   cd backend
   python3 -m venv .venv
   source .venv/bin/activate        # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env
   # edit .env — at minimum set a real JWT_SECRET_KEY
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

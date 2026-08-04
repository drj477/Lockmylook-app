# Sprint Log

## Sprint 1 — Foundation + Auth + Profiles (v0.1)

**Goal:** register → login → JWT → create profile → list profiles →
switch profile → logout.

**Delivered:**
- FastAPI app with centralized config, logging, and exception handling
- Dockerized PostgreSQL (infra-only), native app execution
- Alembic migration for `accounts` + `profiles`
- `POST /auth/signup`, `/login`, `/refresh`, `/logout`
- `POST /profiles`, `GET /profiles`, `GET /profiles/{id}`, `DELETE /profiles/{id}`
- Ownership enforcement on every profile endpoint (404-not-403 pattern)
- Test suite: signup, login, JWT validity, profile-ownership (mandatory
  per architecture doc)
- Pre-commit: Black, isort, Ruff, Pyright on commit; Pytest on push
- **Post-review additions:** app factory (`create_app()`), fail-fast DB
  check on startup, request-ID correlation middleware + logging, success
  responses wrapped in the same `Envelope` used for errors, centralized
  password-strength validator (`core/validators.py`), `pool_recycle` on
  the DB engine
- **Explicitly declined from review:** refresh-token revocation table
  (see Architecture.md → "Explicitly deferred") — flagged as scope creep
  against the frozen MVP philosophy; revisit only on concrete need

**Not built yet (by design):** wardrobe, outfits, AI, background jobs,
caching. See `Architecture.md` → "Explicitly deferred."

**Next sprint (Sprint 2):** wardrobe upload — one clothing item, view it,
delete it. No AI detection yet.

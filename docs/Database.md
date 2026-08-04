# Database Schema — Sprint 1

## `accounts`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| email | string, unique, indexed | |
| hashed_password | string | Argon2 |
| is_active | boolean, default true | for future account disabling |
| created_at | timestamptz | |

## `profiles`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| account_id | UUID (FK → accounts.id, indexed, cascade delete) | |
| name | string | |
| avatar_url | string, nullable | |
| created_at | timestamptz | |

One account → many profiles (Netflix-style family members).

## Migration

`alembic/versions/0001_initial_accounts_profiles.py` creates both tables.
Run with:
```bash
alembic upgrade head
```

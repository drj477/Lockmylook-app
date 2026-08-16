# LockMyLook backend

## Local PostgreSQL

The backend uses PostgreSQL by default. A local PostgreSQL service is provided in `docker-compose.yml` so a fresh checkout does not depend on a manually installed database server.

From this directory:

```bash
docker compose up -d postgres
```

Wait for PostgreSQL to become healthy:

```bash
docker compose ps
```

Then create your local environment file:

```bash
cp .env.example .env
```

Install dependencies in the virtual environment:

```bash
python -m pip install -r requirements.txt
```

Verify the environment:

```bash
python -m pip check
pytest -q
```

Apply migrations:

```bash
alembic upgrade head
```

Start the API:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open the API docs at `http://localhost:8000/docs`.

## Virtual Try-On providers

Replicate remains supported. Gemini is an additional selectable provider.

Set the relevant key in `.env`:

```dotenv
REPLICATE_API_TOKEN=
GEMINI_API_KEY=
GEMINI_IMAGE_MODEL=gemini-3.1-flash-image
GEMINI_IMAGE_SIZE=2K
```

A provider that has no API key configured fails with a clear configuration error; it does not silently fall back to another provider.

## Stopping PostgreSQL

```bash
docker compose stop postgres
```

To remove the container and local database volume as well:

```bash
docker compose down -v
```

Do not run `down -v` if you need to preserve local data.

## Common database error

If `alembic upgrade head` reports `connection to server at "127.0.0.1", port 5432 failed: Connection refused`, PostgreSQL is not running. Start it with:

```bash
docker compose up -d postgres
```

Then retry:

```bash
alembic upgrade head
```

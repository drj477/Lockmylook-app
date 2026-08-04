from collections.abc import Generator

from sqlmodel import Session, create_engine

from app.core.config import get_settings

settings = get_settings()

engine = create_engine(
    settings.DATABASE_URL,
    echo=False,  # set True locally if you want to see generated SQL
    pool_pre_ping=True,  # detects and discards dead connections before use
    pool_recycle=1800,  # recycle connections every 30 min, avoids stale
                        # connections being closed server-side (e.g. by a
                        # managed Postgres provider's idle-connection reaper)
)


def get_session() -> Generator[Session, None, None]:
    """FastAPI dependency: one session per request, always closed."""
    with Session(engine) as session:
        yield session

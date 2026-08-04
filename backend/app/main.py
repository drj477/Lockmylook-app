from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from loguru import logger
from sqlalchemy import text

from app.auth.router import router as auth_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.health import router as health_router
from app.core.logging import configure_logging
from app.core.middleware import RequestIDMiddleware
from app.database import session as db_session
from app.profiles.router import router as profiles_router
from app.wardrobe.router import router as wardrobe_router  # NEW


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Application startup/shutdown lifecycle."""

    try:
        with db_session.engine.connect() as connection:
            connection.execute(text("SELECT 1"))

        logger.info("Database connection verified at startup.")

    except Exception as exc:
        logger.exception("Database connection failed at startup.")
        raise

    yield

    logger.info("Application shutdown complete.")


def create_app() -> FastAPI:
    """Application factory."""

    settings = get_settings()

    configure_logging()

    app = FastAPI(
        title=settings.APP_NAME,
        version="0.2.0",
        lifespan=lifespan,
    )

    # Middleware
    app.add_middleware(RequestIDMiddleware)

    # Exception Handlers
    register_exception_handlers(app)

    # Core
    app.include_router(
        health_router,
        prefix=settings.API_V1_PREFIX,
    )

    # Authentication
    app.include_router(
        auth_router,
        prefix=settings.API_V1_PREFIX,
    )

    # Profiles
    app.include_router(
        profiles_router,
        prefix=settings.API_V1_PREFIX,
    )

    # Wardrobe
    app.include_router(
        wardrobe_router,
        prefix=settings.API_V1_PREFIX,
    )

    return app


app = create_app()
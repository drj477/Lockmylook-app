import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from loguru import logger
from sqlalchemy import text

from app.auth.router import router as auth_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.health import router as health_router
from app.core.logging import configure_logging
from app.core.middleware import RequestIDMiddleware
from app.credits.router import router as credits_router
from app.database import session as db_session
from app.outfits.router import router as outfits_router
from app.profiles.router import router as profiles_router
from app.purchases.router import router as purchases_router
from app.virtual_try_on.router import router as virtual_try_on_router
from app.wardrobe.category_router import router as wardrobe_category_router
from app.wardrobe.image_router import router as wardrobe_image_router
from app.wardrobe.router import router as wardrobe_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Application startup/shutdown lifecycle."""

    try:
        with db_session.engine.connect() as connection:
            connection.execute(text("SELECT 1"))

        logger.info("Database connection verified at startup.")

    except Exception:
        logger.exception("Database connection failed at startup.")
        raise

    yield

    # VirtualTryOnService does not currently own a closeable resource.
    # Gemini Chat's underlying client lifecycle is managed by its provider/
    # library, so do not call a nonexistent service.close() during shutdown.
    logger.info("Application shutdown complete.")


def create_app() -> FastAPI:
    """Application factory."""

    settings = get_settings()

    configure_logging()

    app = FastAPI(
        title=settings.APP_NAME,
        version="0.3.0",
        lifespan=lifespan,
    )

    app.add_middleware(RequestIDMiddleware)
    register_exception_handlers(app)

    app.include_router(health_router, prefix=settings.API_V1_PREFIX)
    app.include_router(auth_router, prefix=settings.API_V1_PREFIX)
    app.include_router(credits_router, prefix=settings.API_V1_PREFIX)
    app.include_router(purchases_router, prefix=settings.API_V1_PREFIX)
    app.include_router(profiles_router, prefix=settings.API_V1_PREFIX)
    app.include_router(
        wardrobe_category_router,
        prefix=settings.API_V1_PREFIX,
    )
    app.include_router(wardrobe_router, prefix=settings.API_V1_PREFIX)
    app.include_router(wardrobe_image_router, prefix=settings.API_V1_PREFIX)
    app.include_router(outfits_router, prefix=settings.API_V1_PREFIX)
    app.include_router(
        virtual_try_on_router,
        prefix=settings.API_V1_PREFIX,
    )

    os.makedirs("uploads/wardrobe", exist_ok=True)
    os.makedirs("uploads/profiles", exist_ok=True)
    os.makedirs("uploads/tryon", exist_ok=True)

    app.mount(
        "/uploads",
        StaticFiles(directory="uploads"),
        name="uploads",
    )

    return app


app = create_app()

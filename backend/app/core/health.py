from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlmodel import Session

from app.core.config import get_settings
from app.core.schema import Envelope
from app.database.session import get_session

router = APIRouter(tags=["health"])


@router.get("/health", response_model=Envelope[dict])
async def health_check(session: Session = Depends(get_session)) -> Envelope[dict]:
    session.exec(text("SELECT 1"))  # confirms DB connectivity, not just app liveness
    settings = get_settings()
    return Envelope(
        message="Service is healthy.",
        data={
            "status": "healthy",
            "version": "0.1.0",
            "environment": settings.ENVIRONMENT,
            "database": "connected",
        },
    )

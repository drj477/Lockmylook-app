import sys

from loguru import logger

from app.core.config import get_settings
from app.core.context import request_id_ctx_var


def _inject_request_id(record: dict) -> None:
    record["extra"]["request_id"] = request_id_ctx_var.get()


def configure_logging() -> None:
    """Configure Loguru once at startup.

    We log meaningful business events (user registered, login, profile
    created) at INFO, and failures at ERROR. We do NOT log request/response
    noise for every endpoint -- that belongs in access logs / APM, not here.

    Every log line is tagged with the current request's correlation ID
    (X-Request-ID), so a single request's logs can be grepped together even
    under concurrent load.
    """
    settings = get_settings()

    logger.remove()  # drop default handler
    logger.configure(patcher=_inject_request_id)
    logger.add(
        sys.stdout,
        level=settings.LOG_LEVEL,
        format=(
            "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
            "<level>{level: <8}</level> | "
            "<yellow>{extra[request_id]}</yellow> | "
            "<cyan>{name}:{function}:{line}</cyan> | "
            "<level>{message}</level>"
        ),
        colorize=True,
        backtrace=False,
        diagnose=settings.ENVIRONMENT == "development",
    )


# Convenience event helpers so call sites read like business events,
# not ad-hoc strings. Extend as new events are introduced.
def log_user_registered(account_id: str, email: str) -> None:
    logger.info("User registered | account_id={} email={}", account_id, email)


def log_user_logged_in(account_id: str) -> None:
    logger.info("User logged in | account_id={}", account_id)


def log_user_logged_out(account_id: str) -> None:
    logger.info("User logged out | account_id={}", account_id)


def log_profile_created(profile_id: str, account_id: str) -> None:
    logger.info("Profile created | profile_id={} account_id={}", profile_id, account_id)


def log_authentication_failed(email: str, reason: str) -> None:
    logger.error("Authentication failed | email={} reason={}", email, reason)

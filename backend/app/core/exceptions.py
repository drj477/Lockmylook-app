from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from loguru import logger


class AppError(Exception):
    """Base class for all application (business-logic) errors.

    Services raise these directly. Routers never catch them — the global
    handler below converts them into the standard response envelope.
    """

    status_code: int = status.HTTP_400_BAD_REQUEST
    message: str = "Something went wrong."

    def __init__(self, message: str | None = None) -> None:
        if message:
            self.message = message
        super().__init__(self.message)


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    message = "Resource not found."


class UnauthorizedError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    message = "Not authenticated."


class ForbiddenError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    message = "Not allowed to perform this action."


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    message = "Resource already exists."


class ValidationFailedError(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    message = "Validation failed."


def _envelope(success: bool, message: str, data: object = None, errors: list | None = None) -> dict:
    return {"success": success, "message": message, "data": data, "errors": errors or []}


def register_exception_handlers(app: FastAPI) -> None:
    """Wire up every exception type to the standard response envelope.
    This is the ONLY place try/except-to-HTTP translation happens.
    """

    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=_envelope(success=False, message=exc.message),
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        errors = [
            {"field": ".".join(str(loc) for loc in err["loc"]), "issue": err["msg"]}
            for err in exc.errors()
        ]
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=_envelope(
                success=False, message="Validation failed.", errors=errors
            ),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        logger.error("Unhandled exception on {} {}: {}", request.method, request.url.path, exc)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=_envelope(success=False, message="Internal server error."),
        )

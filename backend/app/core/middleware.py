import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from app.core.context import request_id_ctx_var


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Attaches a correlation ID to every request.

    If the client sent X-Request-ID, we reuse it (useful when a request
    already has an ID from an upstream gateway/mobile client). Otherwise we
    generate one. The ID is stored in a contextvar for the duration of the
    request so every log line emitted while handling it can be tagged with
    the same ID (see core/logging.py), and it's echoed back in the response
    header so the client can correlate too.
    """

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        token = request_id_ctx_var.set(request_id)
        try:
            response = await call_next(request)
        finally:
            request_id_ctx_var.reset(token)
        response.headers["X-Request-ID"] = request_id
        return response

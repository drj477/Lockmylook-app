from contextvars import ContextVar

# Set by RequestIDMiddleware at the start of every request, read by the
# logging patcher so every log line during that request carries the same ID.
request_id_ctx_var: ContextVar[str] = ContextVar("request_id", default="-")

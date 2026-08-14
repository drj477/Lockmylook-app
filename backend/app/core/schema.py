from typing import TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class Envelope[T](BaseModel):
    """The standard shape for every API response, success or error:
    {"success": bool, "message": str, "data": ..., "errors": [...]}

    Error responses are wrapped by the global exception handlers in
    core/exceptions.py. Success responses are wrapped explicitly by each
    router using this class, so the shape is consistent everywhere.
    """

    success: bool = True
    message: str
    data: T | None = None
    errors: list = []
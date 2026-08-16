from uuid import uuid4

from app.virtual_try_on.model import VirtualTryOnModel
from app.virtual_try_on.schema import VirtualTryOnRequest


def test_virtual_try_on_request_defaults_to_replicate():
    request = VirtualTryOnRequest(item_ids=[uuid4()])

    assert request.model is VirtualTryOnModel.REPLICATE


def test_virtual_try_on_request_accepts_gemini():
    request = VirtualTryOnRequest(
        item_ids=[uuid4()],
        model=VirtualTryOnModel.GEMINI,
    )

    assert request.model is VirtualTryOnModel.GEMINI


def test_virtual_try_on_request_accepts_gemini_chat():
    request = VirtualTryOnRequest(
        item_ids=[uuid4()],
        model=VirtualTryOnModel.GEMINI_CHAT,
    )

    assert request.model is VirtualTryOnModel.GEMINI_CHAT

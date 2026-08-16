import pytest

from app.virtual_try_on.gemini_chat.client import (
    GeminiChatClient,
    GeminiChatConfigurationError,
)
from app.virtual_try_on.gemini_chat.provider import GeminiChatVirtualTryOnProvider
from app.virtual_try_on.providers import _read_provider_output


class _Settings:
    GEMINI_CHAT_COOKIE_JSON = ""
    GEMINI_CHAT_COOKIE_CACHE_DIR = "secrets/gemini_webapi"
    GEMINI_CHAT_TIMEOUT_SECONDS = 450


def test_provider_output_accepts_file_like_object():
    class _File:
        def read(self):
            return b"image-bytes"

    assert _read_provider_output(_File()) == b"image-bytes"


def test_gemini_chat_provider_is_isolated():
    provider = GeminiChatVirtualTryOnProvider(_Settings())

    assert isinstance(provider._client, GeminiChatClient)


@pytest.mark.asyncio
async def test_gemini_chat_requires_server_side_cookie():
    provider = GeminiChatVirtualTryOnProvider(_Settings())

    with pytest.raises(GeminiChatConfigurationError, match="GEMINI_CHAT_COOKIE_JSON"):
        await provider.generate(
            person_path=__import__("pathlib").Path("person.png"),
            garment_paths=[],
            garment_names=[],
            prompt="test",
        )

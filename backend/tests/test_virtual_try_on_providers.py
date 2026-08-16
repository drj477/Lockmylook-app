from pathlib import Path

import pytest

from app.virtual_try_on.providers import GeminiVirtualTryOnProvider, _image_input


class _Settings:
    GEMINI_API_KEY = ""
    GEMINI_IMAGE_MODEL = "gemini-3.1-flash-image"
    GEMINI_IMAGE_SIZE = "2K"


def test_gemini_image_input_encodes_local_file(tmp_path):
    image = tmp_path / "person.png"
    image.write_bytes(b"png-bytes")

    payload = _image_input(image)

    assert payload["type"] == "image"
    assert payload["mime_type"] == "image/png"
    assert payload["data"]


def test_gemini_provider_requires_api_key(tmp_path):
    person = tmp_path / "person.png"
    person.write_bytes(b"png-bytes")

    provider = GeminiVirtualTryOnProvider(_Settings())

    with pytest.raises(RuntimeError, match="GEMINI_API_KEY"):
        provider.generate(
            person_path=Path(person),
            garment_paths=[],
            garment_names=[],
            prompt="test",
        )

from __future__ import annotations

import asyncio
import base64
import mimetypes
from contextlib import ExitStack
from pathlib import Path
from typing import Protocol

from google import genai
from loguru import logger
from replicate.client import Client

from app.core.config import Settings
from app.virtual_try_on.gemini_chat import GeminiChatVirtualTryOnProvider


class VirtualTryOnProvider(Protocol):
    async def generate(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        """Generate a try-on image and return its raw bytes."""


class ReplicateVirtualTryOnProvider:
    MODEL = "prunaai/p-image-try-on"

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def generate(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        return await asyncio.to_thread(
            self._generate_sync,
            person_path,
            garment_paths,
            garment_names,
            prompt,
        )

    def _generate_sync(
        self,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        del garment_names

        if not self._settings.REPLICATE_API_TOKEN:
            raise RuntimeError("REPLICATE_API_TOKEN is not configured.")

        with ExitStack() as stack:
            person_file = stack.enter_context(person_path.open("rb"))
            garment_files = [
                stack.enter_context(path.open("rb"))
                for path in garment_paths
            ]

            client = Client(api_token=self._settings.REPLICATE_API_TOKEN)
            output = client.run(
                self.MODEL,
                input={
                    "person_image": person_file,
                    "garment_images": garment_files,
                    "prompt": prompt,
                    "turbo": False,
                    "preserve_input_size": True,
                    "output_format": "webp",
                    "output_quality": 100,
                },
                wait=60,
            )

        return _read_provider_output(output)


class GeminiVirtualTryOnProvider:
    """Existing Gemini image-editing provider for multi-reference VTO."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def generate(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        return await asyncio.to_thread(
            self._generate_sync,
            person_path,
            garment_paths,
            garment_names,
            prompt,
        )

    def _generate_sync(
        self,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        del garment_names

        if not self._settings.GEMINI_API_KEY:
            raise RuntimeError("GEMINI_API_KEY is not configured.")

        client = genai.Client(api_key=self._settings.GEMINI_API_KEY)
        inputs: list[dict[str, str]] = [
            {"type": "text", "text": prompt},
            _image_input(person_path),
        ]
        inputs.extend(_image_input(path) for path in garment_paths)

        logger.info(
            "Calling Gemini image model={} with {} reference images.",
            self._settings.GEMINI_IMAGE_MODEL,
            len(garment_paths) + 1,
        )

        interaction = client.interactions.create(
            model=self._settings.GEMINI_IMAGE_MODEL,
            input=inputs,
            response_format={
                "type": "image",
                "image_size": self._settings.GEMINI_IMAGE_SIZE,
            },
        )

        output_image = getattr(interaction, "output_image", None)
        if output_image is None or not getattr(output_image, "data", None):
            raise RuntimeError("Gemini completed without returning an image.")

        return base64.b64decode(output_image.data)


def _image_input(path: Path) -> dict[str, str]:
    mime_type, _ = mimetypes.guess_type(path.name)
    return {
        "type": "image",
        "data": base64.b64encode(path.read_bytes()).decode("ascii"),
        "mime_type": mime_type or "application/octet-stream",
    }


__all__ = [
    "GeminiChatVirtualTryOnProvider",
    "GeminiVirtualTryOnProvider",
    "ReplicateVirtualTryOnProvider",
    "VirtualTryOnProvider",
]


def _read_provider_output(output) -> bytes:
    """Normalize Replicate SDK file output into bytes."""
    if output is None:
        return b""

    if hasattr(output, "read"):
        return output.read()

    if isinstance(output, list | tuple):
        if not output:
            return b""
        first = output[0]
        if hasattr(first, "read"):
            return first.read()
        if isinstance(first, bytes | bytearray):
            return bytes(first)

    if isinstance(output, bytes | bytearray):
        return bytes(output)

    raise RuntimeError(
        f"Unsupported provider output type: {type(output).__name__}"
    )

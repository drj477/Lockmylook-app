from __future__ import annotations

from pathlib import Path

from app.core.config import Settings

from .client import GeminiChatClient


class GeminiChatVirtualTryOnProvider:
    """Experimental Gemini Web API VTO provider kept isolated for testing."""

    def __init__(self, settings: Settings) -> None:
        self._client = GeminiChatClient(settings)

    async def generate(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        del garment_names
        return await self._client.generate_try_on(
            person_path=person_path,
            garment_paths=garment_paths,
            prompt=prompt,
        )

    async def close(self) -> None:
        await self._client.close()

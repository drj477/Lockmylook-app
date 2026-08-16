from __future__ import annotations

import asyncio
import json
import os
import tempfile
from pathlib import Path

from gemini_webapi import AuthError, GeminiClient, GeneratedImage

from app.core.config import Settings


class GeminiChatConfigurationError(RuntimeError):
    """Raised when the server-side Gemini Chat credentials are not configured."""


class GeminiChatAuthenticationError(RuntimeError):
    """Raised when Gemini rejects the configured browser session."""


class GeminiChatClient:
    """Small lifecycle wrapper around the proven gemini_webapi client.

    The browser cookie JSON is used only as the initial credential source. The
    underlying library maintains a refreshed cookie cache in GEMINI_COOKIE_PATH,
    allowing a long-running backend to keep the session alive without putting
    credentials in the mobile app.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: GeminiClient | None = None
        self._init_lock = asyncio.Lock()
        self._generation_lock = asyncio.Lock()

    async def _get_client(self) -> GeminiClient:
        client = self._client
        if client is not None and client.account_status.name == "AVAILABLE":
            return client

        async with self._init_lock:
            client = self._client
            if client is not None and client.account_status.name == "AVAILABLE":
                return client

            cookie_path = self._resolve_cookie_path()
            secure_1psid, secure_1psidts = self._load_cookies(cookie_path)

            cache_dir = self._resolve_cache_dir()
            cache_dir.mkdir(parents=True, exist_ok=True)
            os.environ["GEMINI_COOKIE_PATH"] = str(cache_dir)

            new_client = GeminiClient(
                secure_1psid,
                secure_1psidts,
                verify=False,
            )

            try:
                await new_client.init(
                    timeout=self._settings.GEMINI_CHAT_TIMEOUT_SECONDS,
                    auto_close=False,
                    auto_refresh=True,
                    verbose=False,
                )
            except AuthError as error:
                await new_client.close()
                raise GeminiChatAuthenticationError(
                    "Gemini Chat authentication failed. Re-export the browser "
                    "cookies and update GEMINI_CHAT_COOKIE_JSON."
                ) from error
            except Exception:
                await new_client.close()
                raise

            self._client = new_client
            return new_client

    async def generate_try_on(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        prompt: str,
    ) -> bytes:
        """Run the proven multimodal Gemini image-editing flow and return bytes."""
        client = await self._get_client()

        # Serialize generations through the same authenticated web session.
        async with self._generation_lock:
            try:
                response = await client.generate_content(
                    prompt,
                    files=[str(person_path), *(str(path) for path in garment_paths)],
                )
            except AuthError as error:
                self._client = None
                await client.close()
                raise GeminiChatAuthenticationError(
                    "Gemini Chat authentication expired. Re-export the browser "
                    "cookies before trying again."
                ) from error

            if not response.images:
                raise RuntimeError("Gemini Chat completed without returning an image.")

            image = next(
                (candidate for candidate in response.images if isinstance(candidate, GeneratedImage)),
                response.images[0],
            )

            with tempfile.TemporaryDirectory(prefix="lockmylook-gemini-chat-") as temp_dir:
                if isinstance(image, GeneratedImage):
                    saved_path = await image.save(
                        path=temp_dir,
                        filename="tryon.png",
                        verbose=False,
                        full_size=True,
                    )
                else:
                    saved_path = await image.save(
                        path=temp_dir,
                        filename="tryon.png",
                        verbose=False,
                    )
                output = Path(saved_path).read_bytes()

            if not output:
                raise RuntimeError("Gemini Chat returned an empty image.")

            return output

    async def close(self) -> None:
        client = self._client
        self._client = None
        if client is not None:
            await client.close()

    def _resolve_cookie_path(self) -> Path:
        raw = self._settings.GEMINI_CHAT_COOKIE_JSON.strip()
        if not raw:
            raise GeminiChatConfigurationError(
                "GEMINI_CHAT_COOKIE_JSON is not configured."
            )

        path = Path(raw)
        if not path.is_absolute():
            path = Path.cwd() / path

        path = path.resolve()
        if not path.exists() or not path.is_file():
            raise GeminiChatConfigurationError(
                f"Gemini Chat cookie JSON was not found: {path}"
            )

        return path

    def _resolve_cache_dir(self) -> Path:
        raw = self._settings.GEMINI_CHAT_COOKIE_CACHE_DIR.strip()
        path = Path(raw or "secrets/gemini_webapi")
        if not path.is_absolute():
            path = Path.cwd() / path
        return path.resolve()

    @staticmethod
    def _load_cookies(path: Path) -> tuple[str, str | None]:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise GeminiChatConfigurationError(
                f"Could not read Gemini Chat cookie JSON: {path}"
            ) from error

        cookies = data.get("cookies") if isinstance(data, dict) else data

        if isinstance(cookies, dict):
            values = cookies
        elif isinstance(cookies, list):
            values = {
                item.get("name"): item.get("value")
                for item in cookies
                if isinstance(item, dict) and item.get("name")
            }
        else:
            raise GeminiChatConfigurationError(
                "Unsupported Gemini Chat cookie JSON format."
            )

        secure_1psid = values.get("__Secure-1PSID")
        secure_1psidts = values.get("__Secure-1PSIDTS")

        if not secure_1psid:
            raise GeminiChatConfigurationError(
                "Gemini Chat cookie JSON does not contain __Secure-1PSID."
            )

        return str(secure_1psid), str(secure_1psidts) if secure_1psidts else None

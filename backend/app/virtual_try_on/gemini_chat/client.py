from __future__ import annotations

import asyncio
import json
import os
import tempfile
from pathlib import Path

from gemini_webapi import AuthError, GeminiClient, GeneratedImage

from app.core.config import Settings


class GeminiChatConfigurationError(RuntimeError):
    """Raised when Gemini Chat credentials are not configured correctly."""


class GeminiChatAuthenticationError(RuntimeError):
    """Raised when Gemini rejects the authenticated Gemini session."""


class GeminiChatClient:
    """
    Gemini Chat client for LockMyLook.

    Credential/session strategy:

    1. GEMINI_CHAT_COOKIE_JSON is the bootstrap credential source.
    2. GEMINI_COOKIE_PATH tells gemini_webapi where its persistent cookie
       cache lives.
    3. gemini_webapi owns normal cache discovery, cookie rotation and
       persistence.
    4. If gemini_webapi selects a cached session that is rejected by its
       authenticated account-status check, this class deletes ONLY the
       cache entry belonging to the configured __Secure-1PSID and retries
       once from the bootstrap cookies.
    5. If a live session is rejected during generation, the same targeted
       cache invalidation/reinitialization is attempted once.

    The browser-exported cookie JSON is never rewritten by this class.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: GeminiClient | None = None
        self._init_lock = asyncio.Lock()
        self._generation_lock = asyncio.Lock()

    async def _get_client(self) -> GeminiClient:
        """Return a currently authenticated Gemini client."""
        client = self._client

        if client is not None:
            try:
                if client.account_status.name == "AVAILABLE":
                    return client
            except Exception:
                pass

        async with self._init_lock:
            client = self._client

            if client is not None:
                try:
                    if client.account_status.name == "AVAILABLE":
                        return client
                except Exception:
                    pass

            cache_dir = self._resolve_cache_dir()
            cache_dir.mkdir(parents=True, exist_ok=True)
            os.environ["GEMINI_COOKIE_PATH"] = str(cache_dir)

            cookie_path = self._resolve_cookie_path()
            secure_1psid, secure_1psidts = self._load_cookies(cookie_path)

            # First attempt allows gemini_webapi to use its persistent cache.
            new_client = await self._init_client(
                secure_1psid,
                secure_1psidts,
            )

            if new_client is not None:
                self._client = new_client
                return new_client

            # A cache entry for this exact PSID can shadow fresh bootstrap
            # cookies. Remove only that entry and retry once.
            removed = self._delete_cached_cookie(secure_1psid)
            if removed:
                new_client = await self._init_client(
                    secure_1psid,
                    secure_1psidts,
                )

                if new_client is not None:
                    self._client = new_client
                    return new_client

            raise GeminiChatAuthenticationError(
                "Gemini Chat authentication failed. The cached session and "
                "the configured bootstrap cookies were rejected. "
                "Re-export the Gemini browser cookies once."
            )

    async def _init_client(
        self,
        secure_1psid: str,
        secure_1psidts: str | None,
    ) -> GeminiClient | None:
        """Initialize one Gemini session; return None for rejected auth."""
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
                refresh_interval=300,
                watchdog_timeout=120,
                verbose=False,
            )

            status = getattr(new_client.account_status, "name", None)

            if status == "AVAILABLE":
                return new_client

            await self._safe_close(new_client)
            return None

        except AuthError:
            await self._safe_close(new_client)
            return None
        except Exception:
            await self._safe_close(new_client)
            raise

    async def generate_try_on(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        prompt: str,
    ) -> bytes:
        """Generate a Virtual Try-On image through Gemini Chat."""
        async with self._generation_lock:
            client = await self._get_client()

            try:
                response = await client.generate_content(
                    prompt,
                    files=[
                        str(person_path),
                        *(str(path) for path in garment_paths),
                    ],
                )
            except AuthError as error:
                # The session may have become invalid after initialization.
                # Drop only this PSID's persistent cache and rebuild once.
                self._client = None
                await self._safe_close(client)

                try:
                    cookie_path = self._resolve_cookie_path()
                    secure_1psid, secure_1psidts = self._load_cookies(cookie_path)
                    self._delete_cached_cookie(secure_1psid)
                    retry_client = await self._get_client()
                    response = await retry_client.generate_content(
                        prompt,
                        files=[
                            str(person_path),
                            *(str(path) for path in garment_paths),
                        ],
                    )
                except AuthError as retry_error:
                    self._client = None
                    raise GeminiChatAuthenticationError(
                        "Gemini Chat authentication expired or was rejected "
                        "after cache recovery. Re-export the Gemini browser "
                        "cookies once."
                    ) from retry_error

            if not response.images:
                raise RuntimeError(
                    "Gemini Chat completed without returning an image."
                )

            image = next(
                (
                    candidate
                    for candidate in response.images
                    if isinstance(candidate, GeneratedImage)
                ),
                response.images[0],
            )

            with tempfile.TemporaryDirectory(
                prefix="lockmylook-gemini-chat-"
            ) as temp_dir:
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
                raise RuntimeError(
                    "Gemini Chat returned an empty image."
                )

            return output

    async def close(self) -> None:
        """Close the live Gemini session."""
        client = self._client
        self._client = None

        if client is not None:
            await self._safe_close(client)

    @staticmethod
    async def _safe_close(client: GeminiClient) -> None:
        """Close a Gemini client without masking the original exception."""
        try:
            await client.close()
        except Exception:
            pass

    def _resolve_cookie_path(self) -> Path:
        """Resolve the browser-exported bootstrap cookie JSON."""
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
        """Resolve the persistent gemini_webapi cookie cache directory."""
        raw = self._settings.GEMINI_CHAT_COOKIE_CACHE_DIR.strip()
        path = Path(raw or "secrets/gemini_webapi")

        if not path.is_absolute():
            path = Path.cwd() / path

        return path.resolve()

    def _delete_cached_cookie(self, secure_1psid: str) -> bool:
        """Delete only the cache entry belonging to one Gemini PSID."""
        if not secure_1psid:
            return False

        cache_path = self._resolve_cache_dir() / (
            f".cached_cookies_{secure_1psid}.json"
        )

        try:
            if not cache_path.is_file():
                return False
            cache_path.unlink()
            return True
        except OSError:
            return False

    @staticmethod
    def _load_cookies(
        path: Path,
    ) -> tuple[str, str | None]:
        """Read the minimum bootstrap credentials required by GeminiClient."""
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

        return (
            str(secure_1psid),
            str(secure_1psidts) if secure_1psidts else None,
        )

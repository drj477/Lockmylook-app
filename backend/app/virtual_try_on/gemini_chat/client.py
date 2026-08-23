from __future__ import annotations

import asyncio
import json
import logging
import os
import tempfile
from pathlib import Path

from gemini_webapi import AuthError, GeminiClient, GeneratedImage

from app.core.config import Settings


logger = logging.getLogger(__name__)


class GeminiChatConfigurationError(RuntimeError):
    """Raised when Gemini Chat credentials are not configured correctly."""


class GeminiChatAuthenticationError(RuntimeError):
    """Raised when Gemini rejects every available Gemini session."""


class GeminiChatClient:
    """
    Gemini Chat client for LockMyLook.

    Authentication/session strategy:

    1. Persistent .cached_cookies_*.json files are the primary session pool.
    2. Each cached PSID is tested independently.
    3. An UNAUTHENTICATED cache is deleted individually and the next cache
       is tried; one dead cache must never block another valid cache.
    4. Only after every cached session fails do we try the browser-exported
       GEMINI_CHAT_COOKIE_JSON bootstrap credentials.
    5. A successful session is handed back to gemini_webapi, which owns
       cookie rotation and persistence.

    The browser-exported cookie JSON is never rewritten by this class.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client: GeminiClient | None = None
        self._active_psid: str | None = None
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

            # ------------------------------------------------------------
            # 1. Try every persistent cache independently.
            # ------------------------------------------------------------
            cached_credentials = self._load_cached_credentials(cache_dir)

            for psid, psidts, cache_path in cached_credentials:
                logger.info(
                    "Trying cached Gemini session: %s",
                    cache_path.name,
                )

                candidate = await self._init_client(psid, psidts)

                if candidate is not None:
                    self._client = candidate
                    self._active_psid = psid
                    logger.info(
                        "Using cached Gemini session: %s",
                        cache_path.name,
                    )
                    return candidate

                # This exact cached PSID was rejected. Delete only it.
                self._delete_cached_cookie(psid)
                logger.warning(
                    "Discarded rejected Gemini cache: %s",
                    cache_path.name,
                )

            # ------------------------------------------------------------
            # 2. No cached session worked. Try the manually exported
            #    browser cookies as the bootstrap source.
            # ------------------------------------------------------------
            cookie_path = self._resolve_cookie_path()
            secure_1psid, secure_1psidts = self._load_cookies(cookie_path)

            logger.info(
                "Trying Gemini bootstrap cookies after cached sessions failed."
            )

            candidate = await self._init_client(
                secure_1psid,
                secure_1psidts,
            )

            if candidate is not None:
                self._client = candidate
                self._active_psid = secure_1psid
                logger.info(
                    "Gemini bootstrap session authenticated successfully."
                )
                return candidate

            raise GeminiChatAuthenticationError(
                "Gemini Chat authentication failed. Every cached Gemini "
                "session and the configured bootstrap cookies were rejected. "
                "Re-export fresh Gemini browser cookies."
            )

    async def _init_client(
        self,
        secure_1psid: str,
        secure_1psidts: str | None,
    ) -> GeminiClient | None:
        """Initialize one Gemini session; return None when auth is rejected."""
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

            # gemini_webapi may print "initialized successfully" even when
            # its user-status RPC says UNAUTHENTICATED. Only AVAILABLE is
            # considered a usable authenticated session.
            status = getattr(new_client.account_status, "name", None)

            if status == "AVAILABLE":
                return new_client

            logger.warning(
                "Gemini session rejected after init: status=%s psid=%s",
                status,
                self._mask_psid(secure_1psid),
            )
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
                # The live session became invalid after initialization.
                # Remove only the session that actually failed, then let
                # _get_client() walk the remaining cache pool.
                failed_psid = self._active_psid
                self._client = None
                self._active_psid = None
                await self._safe_close(client)

                if failed_psid:
                    self._delete_cached_cookie(failed_psid)
                    logger.warning(
                        "Live Gemini session expired; discarded cache for PSID %s.",
                        self._mask_psid(failed_psid),
                    )

                try:
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
                    self._active_psid = None
                    raise GeminiChatAuthenticationError(
                        "Gemini Chat authentication expired and no cached "
                        "Gemini session could recover it. Re-export fresh "
                        "Gemini browser cookies once."
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
        self._active_psid = None

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

    @staticmethod
    def _load_cached_credentials(
        cache_dir: Path,
    ) -> list[tuple[str, str | None, Path]]:
        """Load all cached Gemini PSID/PSIDTS pairs, newest first."""
        entries: list[tuple[str, str | None, Path, float]] = []

        for path in cache_dir.glob(".cached_cookies_*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                if not isinstance(data, list):
                    continue

                values = {
                    item.get("name"): item.get("value")
                    for item in data
                    if isinstance(item, dict) and item.get("name")
                }

                psid = values.get("__Secure-1PSID")
                psidts = values.get("__Secure-1PSIDTS")

                if not psid:
                    continue

                entries.append(
                    (
                        str(psid),
                        str(psidts) if psidts else None,
                        path,
                        path.stat().st_mtime,
                    )
                )
            except (OSError, json.JSONDecodeError, ValueError):
                logger.warning(
                    "Ignoring unreadable Gemini cache: %s",
                    path,
                )

        entries.sort(key=lambda item: item[3], reverse=True)
        return [(psid, psidts, path) for psid, psidts, path, _ in entries]

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
        except OSError as error:
            logger.warning(
                "Could not delete rejected Gemini cache %s: %s",
                cache_path,
                error,
            )
            return False

    @staticmethod
    def _mask_psid(psid: str) -> str:
        if len(psid) <= 8:
            return "***"
        return f"{psid[:4]}...{psid[-4:]}"

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

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

    Credential strategy:

    1. GEMINI_CHAT_COOKIE_JSON is used as the bootstrap credential source.
    2. gemini_webapi stores the authenticated/rotated session in
       GEMINI_COOKIE_PATH.
    3. On subsequent initializations gemini_webapi tries the cached session
       before the bootstrap cookies.
    4. gemini_webapi automatically rotates __Secure-1PSIDTS in the background.
    5. The refreshed cookie cache therefore becomes the persistent session
       source across backend restarts.

    The browser-exported cookie JSON is NOT rewritten by this class.
    The cache maintained by gemini_webapi is the mutable credential store.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

        self._client: GeminiClient | None = None

        # Prevent two requests from initializing two Gemini sessions at once.
        self._init_lock = asyncio.Lock()

        # Gemini generations are serialized through one authenticated session.
        self._generation_lock = asyncio.Lock()

    async def _get_client(self) -> GeminiClient:
        """
        Return the authenticated Gemini client.

        The important part here is that GEMINI_COOKIE_PATH is configured
        BEFORE GeminiClient.init() is called.

        gemini_webapi then performs:

            cached cookies -> bootstrap cookies -> browser cookies

        with cached cookies taking priority when the same __Secure-1PSID
        exists in the cache.
        """

        client = self._client

        if client is not None:
            try:
                if client.account_status.name == "AVAILABLE":
                    return client
            except Exception:
                # If the existing client has become unusable, rebuild it.
                pass

        async with self._init_lock:
            client = self._client

            if client is not None:
                try:
                    if client.account_status.name == "AVAILABLE":
                        return client
                except Exception:
                    pass

            # ------------------------------------------------------------
            # Configure persistent cookie cache FIRST.
            # ------------------------------------------------------------
            cache_dir = self._resolve_cache_dir()
            cache_dir.mkdir(parents=True, exist_ok=True)

            # gemini_webapi reads this environment variable dynamically.
            os.environ["GEMINI_COOKIE_PATH"] = str(cache_dir)

            # ------------------------------------------------------------
            # Load bootstrap credentials.
            #
            # These are only needed to identify the account/session on the
            # first run or if the persistent cache is unavailable.
            # ------------------------------------------------------------
            cookie_path = self._resolve_cookie_path()
            secure_1psid, secure_1psidts = self._load_cookies(cookie_path)

            # ------------------------------------------------------------
            # Create Gemini client.
            #
            # gemini_webapi itself will check its persistent cache before
            # falling back to the credentials supplied here.
            # ------------------------------------------------------------
            new_client = GeminiClient(
                secure_1psid,
                secure_1psidts,
                verify=False,
            )

            try:
                await new_client.init(
                    timeout=self._settings.GEMINI_CHAT_TIMEOUT_SECONDS,

                    # We want this backend to stay alive.
                    auto_close=False,

                    # CRITICAL:
                    # Keep cookie/token rotation enabled.
                    auto_refresh=True,

                    # Refresh considerably before the session gets stale.
                    #
                    # gemini_webapi adds a small random jitter and enforces
                    # a minimum of 60 seconds.
                    refresh_interval=300,

                    # Stream watchdog.
                    watchdog_timeout=120,

                    verbose=False,
                )

            except AuthError as error:
                await new_client.close()

                raise GeminiChatAuthenticationError(
                    "Gemini Chat authentication failed. "
                    "The persistent Gemini session and bootstrap cookies "
                    "were rejected. Re-export the browser cookies once."
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
        """
        Generate a Virtual Try-On image through Gemini Chat.
        """

        client = await self._get_client()

        # One authenticated Gemini session handles generations sequentially.
        async with self._generation_lock:
            try:
                response = await client.generate_content(
                    prompt,
                    files=[
                        str(person_path),
                        *(str(path) for path in garment_paths),
                    ],
                )

            except AuthError as error:
                # The authenticated session is no longer usable.
                #
                # Do NOT delete the persistent cache here.
                # gemini_webapi owns the cache and may already have rotated
                # the session credentials.
                self._client = None

                try:
                    await client.close()
                except Exception:
                    pass

                raise GeminiChatAuthenticationError(
                    "Gemini Chat authentication expired or was rejected."
                ) from error

            if not response.images:
                raise RuntimeError(
                    "Gemini Chat completed without returning an image."
                )

            # Prefer GeneratedImage because it supports the full-size save
            # path used by the existing VTO implementation.
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
        """
        Close the live Gemini session.

        gemini_webapi saves the persistent cookie state when closing.
        """

        client = self._client
        self._client = None

        if client is not None:
            await client.close()

    def _resolve_cookie_path(self) -> Path:
        """
        Resolve the browser-exported bootstrap cookie JSON.
        """

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
        """
        Resolve the persistent gemini_webapi cookie cache directory.
        """

        raw = self._settings.GEMINI_CHAT_COOKIE_CACHE_DIR.strip()

        path = Path(raw or "secrets/gemini_webapi")

        if not path.is_absolute():
            path = Path.cwd() / path

        return path.resolve()

    @staticmethod
    def _load_cookies(
        path: Path,
    ) -> tuple[str, str | None]:
        """
        Read the minimum bootstrap credentials required by GeminiClient.

        Supports both:

            [
                {"name": "...", "value": "..."},
                ...
            ]

        and:

            {
                "cookies": [
                    ...
                ]
            }

        formats.
        """

        try:
            data = json.loads(
                path.read_text(encoding="utf-8")
            )

        except (OSError, json.JSONDecodeError) as error:
            raise GeminiChatConfigurationError(
                f"Could not read Gemini Chat cookie JSON: {path}"
            ) from error

        cookies = (
            data.get("cookies")
            if isinstance(data, dict)
            else data
        )

        if isinstance(cookies, dict):
            values = cookies

        elif isinstance(cookies, list):
            values = {
                item.get("name"): item.get("value")
                for item in cookies
                if (
                    isinstance(item, dict)
                    and item.get("name")
                )
            }

        else:
            raise GeminiChatConfigurationError(
                "Unsupported Gemini Chat cookie JSON format."
            )

        secure_1psid = values.get("__Secure-1PSID")
        secure_1psidts = values.get("__Secure-1PSIDTS")

        if not secure_1psid:
            raise GeminiChatConfigurationError(
                "Gemini Chat cookie JSON does not contain "
                "__Secure-1PSID."
            )

        return (
            str(secure_1psid),
            (
                str(secure_1psidts)
                if secure_1psidts
                else None
            ),
        )
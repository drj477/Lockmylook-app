from __future__ import annotations

import asyncio
from pathlib import Path
from urllib.parse import quote
from uuid import uuid4

import httpx
from PIL import Image

from app.core.config import Settings


class DTryOnVirtualTryOnProvider:
    """Direct Pruna P-Image-Try-On provider used by the D-Tryon option."""

    MODEL = "p-image-try-on"
    CREATE_URL = "https://api.pruna.ai/v1/predictions"

    POLL_INTERVAL_SECONDS = 2
    MAX_POLL_ATTEMPTS = 150

    # Same cream background already used by the Flutter result screen.
    CREAM_BACKGROUND = (255, 251, 247)

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
        del garment_names, prompt

        if not self._settings.PRUNA_API_KEY:
            raise RuntimeError("PRUNA_API_KEY is not configured.")

        if not self._settings.PRUNA_PUBLIC_BASE_URL:
            raise RuntimeError(
                "PRUNA_PUBLIC_BASE_URL is not configured. "
                "Pruna must be able to reach the uploaded images over HTTPS."
            )

        # ------------------------------------------------------------
        # IMPORTANT:
        #
        # profile.vto_asset_url is intentionally transparent.
        # Do NOT modify the original VTO asset.
        #
        # Pruna/P-Image-Try-On can return black where transparent pixels
        # exist, so D-Tryon receives a temporary cream-background copy.
        # ------------------------------------------------------------
        prepared_person_path = await asyncio.to_thread(
            self._create_pruna_person_image,
            person_path,
        )

        try:
            person_url = self._public_image_url(prepared_person_path)

            garment_urls = [
                self._public_image_url(path)
                for path in garment_paths
            ]

            headers = {
                "apikey": self._settings.PRUNA_API_KEY,
                "Model": self.MODEL,
                "Content-Type": "application/json",
            }

            payload = {
                "input": {
                    "person_image": person_url,
                    "garment_images": garment_urls,
                },
            }

            timeout = httpx.Timeout(60.0, connect=30.0)

            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    self.CREATE_URL,
                    headers=headers,
                    json=payload,
                )

                self._raise_for_pruna(
                    response,
                    "creating prediction",
                )

                prediction = response.json()
                status_url = prediction.get("get_url")

                if not status_url:
                    raise RuntimeError(
                        "Pruna created the prediction but did not return "
                        "a status URL."
                    )

                status_headers = {
                    "apikey": self._settings.PRUNA_API_KEY,
                }

                for _ in range(self.MAX_POLL_ATTEMPTS):
                    status_response = await client.get(
                        status_url,
                        headers=status_headers,
                    )

                    self._raise_for_pruna(
                        status_response,
                        "checking prediction status",
                    )

                    result = status_response.json()
                    status = result.get("status")

                    if status == "succeeded":
                        generation_url = result.get("generation_url")

                        if not generation_url:
                            raise RuntimeError(
                                "Pruna completed the prediction without "
                                "returning a generation URL."
                            )

                        image_response = await client.get(
                            generation_url,
                        )

                        image_response.raise_for_status()

                        if not image_response.content:
                            raise RuntimeError(
                                "Pruna returned an empty generated image."
                            )

                        return image_response.content

                    if status in {"failed", "canceled"}:
                        detail = (
                            result.get("error")
                            or result.get("message")
                            or status
                        )

                        raise RuntimeError(
                            f"Pruna P-Image-Try-On {status}: {detail}"
                        )

                    await _sleep(self.POLL_INTERVAL_SECONDS)

            raise RuntimeError(
                "Pruna P-Image-Try-On timed out while waiting for "
                "the generated image."
            )

        finally:
            # The temporary image only exists so Cloudflare/Pruna can
            # download it. It must not become a permanent profile asset.
            self._delete_temporary_file(prepared_person_path)

    def _create_pruna_person_image(
        self,
        source_path: Path,
    ) -> Path:
        """
        Create a temporary RGB person image with the LockMyLook cream
        background.

        The original transparent VTO asset is never modified.
        """

        uploads_root = (Path.cwd() / "uploads").resolve()

        temp_dir = uploads_root / "vto_pruna_temp"
        temp_dir.mkdir(
            parents=True,
            exist_ok=True,
        )

        output_path = temp_dir / f"{uuid4()}.png"

        try:
            with Image.open(source_path) as source:
                rgba = source.convert("RGBA")

                background = Image.new(
                    "RGBA",
                    rgba.size,
                    self.CREAM_BACKGROUND + (255,),
                )

                composited = Image.alpha_composite(
                    background,
                    rgba,
                )

                # Pruna receives a normal RGB PNG.
                composited.convert("RGB").save(
                    output_path,
                    format="PNG",
                )

        except Exception as error:
            try:
                output_path.unlink(missing_ok=True)
            except OSError:
                pass

            raise RuntimeError(
                "Could not prepare the profile image for D-Tryon."
            ) from error

        return output_path

    def _public_image_url(
        self,
        path: Path,
    ) -> str:
        uploads_root = (Path.cwd() / "uploads").resolve()

        try:
            relative = path.resolve().relative_to(
                uploads_root,
            )
        except ValueError as error:
            raise RuntimeError(
                f"Image is outside the application's uploads directory: "
                f"{path}"
            ) from error

        relative_url = quote(
            relative.as_posix(),
            safe="/",
        )

        return (
            f"{self._settings.PRUNA_PUBLIC_BASE_URL.rstrip('/')}"
            f"/uploads/{relative_url}"
        )

    @staticmethod
    def _delete_temporary_file(
        path: Path,
    ) -> None:
        try:
            path.unlink(missing_ok=True)
        except OSError:
            pass

    @staticmethod
    def _raise_for_pruna(
        response: httpx.Response,
        operation: str,
    ) -> None:
        if response.is_success:
            return

        detail = response.text.strip()

        raise RuntimeError(
            f"Pruna API error while {operation}: "
            f"HTTP {response.status_code} {detail}"
        )


async def _sleep(seconds: int) -> None:
    await asyncio.sleep(seconds)


__all__ = ["DTryOnVirtualTryOnProvider"]
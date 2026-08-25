from __future__ import annotations

import io
from pathlib import Path
from threading import Lock

from loguru import logger
from PIL import Image, ImageOps

from app.profiles.background_removal import _get_session

CREAM_BACKGROUND = (248, 247, 246, 255)


def remove_garment_background(image_bytes: bytes) -> bytes:
    """Remove the garment background with the existing BiRefNet session.

    The segmentation model is shared with the existing VTO background-removal
    infrastructure, but garment framing/output is intentionally separate from
    the person/VTO normalization pipeline.
    """
    if not image_bytes:
        raise ValueError("Garment image cannot be empty.")

    from rembg import remove

    with Image.open(io.BytesIO(image_bytes)) as source:
        source = ImageOps.exif_transpose(source).convert("RGB")
        normalized_input = io.BytesIO()
        source.save(normalized_input, format="PNG", optimize=True)

    output = remove(
        normalized_input.getvalue(),
        session=_get_session(),
        alpha_matting=False,
        post_process_mask=False,
        force_return_bytes=True,
    )

    if not output:
        raise RuntimeError("Garment background removal returned an empty image.")

    with Image.open(io.BytesIO(output)).convert("RGBA") as isolated:
        alpha = isolated.getchannel("A")
        if alpha.getbbox() is None:
            raise RuntimeError("Garment background removal did not detect a garment.")

        bbox_mask = alpha.point(lambda value: 255 if value >= 32 else 0)
        bbox = bbox_mask.getbbox() or alpha.getbbox()
        if bbox is None:
            raise RuntimeError("Garment background removal produced an empty mask.")

        left, top, right, bottom = bbox
        width = right - left
        height = bottom - top
        pad_x = max(12, int(width * 0.06))
        pad_y = max(12, int(height * 0.06))
        left = max(0, left - pad_x)
        top = max(0, top - pad_y)
        right = min(isolated.width, right + pad_x)
        bottom = min(isolated.height, bottom + pad_y)
        cropped = isolated.crop((left, top, right, bottom))

        target = (1024, 1024)
        scale = min(900 / cropped.width, 900 / cropped.height)
        resized = cropped.resize(
            (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
            Image.Resampling.LANCZOS,
        )

        canvas = Image.new("RGBA", target, CREAM_BACKGROUND)
        x = (target[0] - resized.width) // 2
        y = (target[1] - resized.height) // 2
        canvas.alpha_composite(resized, (x, y))

        result = io.BytesIO()
        canvas.convert("RGB").save(result, format="JPEG", quality=95, optimize=True)
        return result.getvalue()

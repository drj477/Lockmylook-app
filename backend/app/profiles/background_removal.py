from __future__ import annotations

import io
import os
from pathlib import Path
from threading import Lock

from loguru import logger

# BiRefNet portrait uses a much higher-resolution segmentation pipeline than
# u2net_human_seg and is better suited to hair, clothing boundaries and feet.
# rembg currently ships this model alongside the U2Net family.
PRIMARY_MODEL_NAME = "birefnet-portrait"
FALLBACK_MODEL_NAME = "u2net_human_seg"
MODEL_DIR = Path(__file__).resolve().parents[2] / "models"

MODEL_DIR.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("U2NET_HOME", str(MODEL_DIR))

_session = None
_session_model_name: str | None = None
_session_lock = Lock()


def _get_session():
    """Create the best available portrait segmentation session once and reuse it."""
    global _session, _session_model_name

    if _session is None:
        with _session_lock:
            if _session is None:
                from rembg import new_session

                try:
                    _session = new_session(PRIMARY_MODEL_NAME)
                    _session_model_name = PRIMARY_MODEL_NAME
                    logger.info("VTO background remover: using {}", PRIMARY_MODEL_NAME)
                except Exception as error:
                    logger.warning(
                        "Could not initialize {} ({}); falling back to {}",
                        PRIMARY_MODEL_NAME,
                        error,
                        FALLBACK_MODEL_NAME,
                    )
                    _session = new_session(FALLBACK_MODEL_NAME)
                    _session_model_name = FALLBACK_MODEL_NAME
                    logger.info("VTO background remover: using {}", FALLBACK_MODEL_NAME)

    return _session


def _clean_alpha(alpha):
    """Remove only invisible fringe; preserve the model's native alpha matte."""
    # Do NOT blur, median-filter, or erode the complete matte here. Those
    # operations soften hair, fingers, shoe/foot contours and garment edges.
    # BiRefNet already produces a continuous alpha matte; preserve it.
    return alpha.point(lambda value: 0 if value < 12 else value)


def _crop_bbox_with_padding(image, padding_ratio: float = 0.04):
    """Crop around meaningful foreground alpha while retaining a small safety margin."""
    alpha = image.getchannel("A")

    # Ignore only weak fringe when calculating the bbox. The original alpha is
    # retained so fine hair and semi-transparent edge detail remain intact.
    bbox_mask = alpha.point(lambda value: 255 if value >= 64 else 0)
    bbox = bbox_mask.getbbox()

    if bbox is None:
        bbox = alpha.getbbox()

    if bbox is None:
        raise RuntimeError("Background removal did not detect a person.")

    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top

    if width < 80 or height < 160:
        raise RuntimeError(
            f"Detected person is unexpectedly small: {width}x{height}."
        )

    pad_x = max(10, int(width * padding_ratio))
    pad_y = max(10, int(height * padding_ratio))

    left = max(0, left - pad_x)
    top = max(0, top - pad_y)
    right = min(image.width, right + pad_x)
    bottom = min(image.height, bottom + pad_y)

    return image.crop((left, top, right, bottom))


def _resize_premultiplied(image, size):
    """Resize RGBA without pulling transparent-background RGB into the edges."""
    import numpy as np
    from PIL import Image

    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3:4] / 255.0
    premultiplied = np.round(rgba[:, :, :3] * alpha).astype(np.uint8)

    rgb = Image.fromarray(premultiplied, mode="RGB").resize(
        size,
        Image.Resampling.LANCZOS,
    )
    resized_alpha = Image.fromarray(
        rgba[:, :, 3].astype(np.uint8),
        mode="L",
    ).resize(size, Image.Resampling.LANCZOS)

    rgb_array = np.asarray(rgb, dtype=np.float32)
    alpha_array = np.asarray(resized_alpha, dtype=np.float32)
    alpha_fraction = alpha_array / 255.0

    # Unpremultiply only where alpha is non-zero. This restores the original
    # foreground colours while keeping transparent pixels black/irrelevant.
    safe_alpha = np.maximum(alpha_fraction, 1.0 / 255.0)
    restored = np.clip(rgb_array / safe_alpha[:, :, None], 0, 255).astype(np.uint8)
    restored[alpha_array == 0] = 0

    result = Image.fromarray(
        np.dstack((restored, alpha_array.astype(np.uint8))),
        mode="RGBA",
    )
    return result


def _normalize_vto_canvas(image, target_size: tuple[int, int] = (1024, 1536)):
    """Place a sharp full-body person on a predictable transparent VTO canvas."""
    from PIL import Image

    target_width, target_height = target_size
    subject_width, subject_height = image.size

    target_subject_height = int(target_height * 0.88)
    target_subject_width = int(target_width * 0.82)
    scale = min(
        target_subject_width / subject_width,
        target_subject_height / subject_height,
    )

    new_size = (
        max(1, round(subject_width * scale)),
        max(1, round(subject_height * scale)),
    )

    # Never use a normal RGBA resize here; premultiplied resampling prevents
    # transparent-background colour contamination at the silhouette boundary.
    image = _resize_premultiplied(image, new_size)

    canvas = Image.new("RGBA", target_size, (0, 0, 0, 0))

    x = (target_width - image.width) // 2
    y = max(0, int(target_height * 0.05))

    if y + image.height > target_height:
        y = target_height - image.height

    canvas.alpha_composite(image, (x, y))
    return canvas


def remove_background(image_bytes: bytes) -> bytes:
    """Return a high-quality, large, normalized transparent full-body VTO PNG."""
    if not image_bytes:
        raise ValueError("Profile photo cannot be empty.")

    from PIL import Image, ImageOps
    from rembg import remove

    # EXIF orientation must be applied before segmentation so the model sees
    # the same orientation the user sees in the original photo.
    with Image.open(io.BytesIO(image_bytes)) as source:
        source = ImageOps.exif_transpose(source).convert("RGB")
        normalized_input = io.BytesIO()
        source.save(normalized_input, format="PNG", optimize=True)
        segmentation_input = normalized_input.getvalue()

    output = remove(
        segmentation_input,
        session=_get_session(),
        # BiRefNet already provides a high-resolution alpha matte. Running the
        # older pymatting stage after it can soften the silhouette unnecessarily.
        alpha_matting=False,
        post_process_mask=False,
        force_return_bytes=True,
    )

    if not output:
        raise RuntimeError("Background removal returned an empty image.")

    with Image.open(io.BytesIO(output)).convert("RGBA") as image:
        image.putalpha(_clean_alpha(image.getchannel("A")))
        cropped = _crop_bbox_with_padding(image)
        normalized = _normalize_vto_canvas(cropped)

        if normalized.getchannel("A").getbbox() is None:
            raise RuntimeError("Background removal produced an empty subject mask.")

        result = io.BytesIO()
        normalized.save(
            result,
            format="PNG",
            optimize=True,
            compress_level=6,
        )
        return result.getvalue()

from __future__ import annotations

import io
import os
from pathlib import Path
from threading import Lock

MODEL_NAME = "u2net_human_seg"
MODEL_DIR = Path(__file__).resolve().parents[2] / "models"

# Keep model weights inside the backend workspace so inference stays local
# after the first download.
MODEL_DIR.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("U2NET_HOME", str(MODEL_DIR))

_session = None
_session_lock = Lock()


def _get_session():
    """Create the human-segmentation session once and reuse it."""
    global _session

    if _session is None:
        with _session_lock:
            if _session is None:
                from rembg import new_session

                _session = new_session(MODEL_NAME)

    return _session


def _clean_alpha(alpha):
    """Clean tiny mask noise while preserving natural subject edges."""
    from PIL import ImageFilter

    # Remove near-transparent background noise first.
    alpha = alpha.point(lambda value: 0 if value < 10 else value)

    # Median filtering removes isolated segmentation speckles.
    alpha = alpha.filter(ImageFilter.MedianFilter(size=3))

    # A very small blur followed by a light sharpening step gives smoother
    # anti-aliased edges without producing a visible hard cutout.
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=0.25))
    return alpha


def _crop_bbox_with_padding(image, padding_ratio: float = 0.06):
    """Crop to the visible subject and add proportional transparent padding."""
    alpha = image.getchannel("A")
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

    pad_x = max(12, int(width * padding_ratio))
    pad_y = max(12, int(height * padding_ratio))

    left = max(0, left - pad_x)
    top = max(0, top - pad_y)
    right = min(image.width, right + pad_x)
    bottom = min(image.height, bottom + pad_y)

    return image.crop((left, top, right, bottom))


def crop_transparent_margins(image_bytes: bytes, padding_ratio: float = 0.06) -> bytes:
    """Return a tightly cropped transparent PNG around the detected person."""
    from PIL import Image

    with Image.open(io.BytesIO(image_bytes)).convert("RGBA") as image:
        image.putalpha(_clean_alpha(image.getchannel("A")))
        cropped = _crop_bbox_with_padding(image, padding_ratio)

        output = io.BytesIO()
        cropped.save(output, format="PNG", optimize=True)
        return output.getvalue()


def _normalize_vto_canvas(image, target_size: tuple[int, int] = (1024, 1536)):
    """Place the person on a predictable transparent full-body VTO canvas."""
    from PIL import Image

    target_width, target_height = target_size

    subject_width, subject_height = image.size
    scale = min(
        target_width / subject_width,
        target_height / subject_height,
        1.0,
    )

    if scale != 1.0:
        image = image.resize(
            (
                max(1, round(subject_width * scale)),
                max(1, round(subject_height * scale)),
            ),
            Image.Resampling.LANCZOS,
        )

    canvas = Image.new("RGBA", target_size, (0, 0, 0, 0))

    # Keep the full body visible while leaving a controlled amount of
    # headroom and avoiding excessive empty space below the feet.
    x = (target_width - image.width) // 2
    y = max(0, int((target_height - image.height) * 0.38))

    canvas.alpha_composite(image, (x, y))
    return canvas


def remove_background(image_bytes: bytes) -> bytes:
    """Return a clean, normalized transparent full-body VTO PNG.

    The pipeline uses the human-specific U2Net segmentation model, then
    performs alpha cleanup, tight subject cropping, proportional padding,
    and deterministic 1024x1536 canvas normalization.
    """
    if not image_bytes:
        raise ValueError("Profile photo cannot be empty.")

    from PIL import Image
    from rembg import remove

    output = remove(
        image_bytes,
        session=_get_session(),
        post_process_mask=True,
        alpha_matting=True,
        alpha_matting_foreground_threshold=240,
        alpha_matting_background_threshold=10,
        alpha_matting_erode_size=8,
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
        normalized.save(result, format="PNG", optimize=True)
        return result.getvalue()

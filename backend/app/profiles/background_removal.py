from __future__ import annotations

import io
import os
from pathlib import Path
from threading import Lock

MODEL_NAME = "u2net_human_seg"
MODEL_DIR = Path(__file__).resolve().parents[2] / "models"

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
    """Remove weak fringe pixels while preserving strong subject detail."""
    from PIL import ImageFilter

    alpha = alpha.point(lambda value: 0 if value < 32 else value)
    alpha = alpha.filter(ImageFilter.MedianFilter(size=3))
    alpha = alpha.filter(ImageFilter.MinFilter(size=3))
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=0.18))
    return alpha


def _crop_bbox_with_padding(image, padding_ratio: float = 0.06):
    """Crop around the real foreground instead of any faint alpha spill."""
    alpha = image.getchannel("A")

    # Image.getbbox() considers every non-zero alpha pixel foreground. Even a
    # tiny amount of segmentation spill can therefore make the crop enormous,
    # which causes the person to appear tiny when Flutter uses BoxFit.contain.
    # Use a stronger threshold for the *bbox only*; the original alpha remains
    # untouched so fine hair/edge detail is not discarded.
    bbox_mask = alpha.point(lambda value: 255 if value >= 96 else 0)
    bbox = bbox_mask.getbbox()

    if bbox is None:
        # Fall back to the cleaned alpha mask if the threshold was too strict.
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
    """Place the person large on a predictable transparent full-body VTO canvas."""
    from PIL import Image

    target_width, target_height = target_size
    subject_width, subject_height = image.size

    # Make the detected subject occupy most of the VTO frame. The crop is now
    # based on meaningful alpha, so transparent background spill cannot shrink
    # the person during this normalization step.
    target_subject_height = int(target_height * 0.88)
    target_subject_width = int(target_width * 0.82)
    scale = min(
        target_subject_width / subject_width,
        target_subject_height / subject_height,
    )

    image = image.resize(
        (
            max(1, round(subject_width * scale)),
            max(1, round(subject_height * scale)),
        ),
        Image.Resampling.LANCZOS,
    )

    canvas = Image.new("RGBA", target_size, (0, 0, 0, 0))

    x = (target_width - image.width) // 2
    y = max(0, int(target_height * 0.06))

    if y + image.height > target_height:
        y = target_height - image.height

    canvas.alpha_composite(image, (x, y))
    return canvas


def remove_background(image_bytes: bytes) -> bytes:
    """Return a clean, large, normalized transparent full-body VTO PNG."""
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
        alpha_matting_erode_size=10,
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

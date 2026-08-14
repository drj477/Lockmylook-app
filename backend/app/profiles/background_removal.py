from __future__ import annotations

import io
import os
from pathlib import Path
from threading import Lock

MODEL_NAME = "u2net_human_seg"
MODEL_DIR = Path(__file__).resolve().parents[2] / "models"

# Keep the model cache inside the backend workspace so inference stays local
# after the model has been downloaded once.
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


def crop_transparent_margins(image_bytes: bytes, padding_ratio: float = 0.06) -> bytes:
    """Crop transparent margins around the detected person in a PNG."""
    from PIL import Image

    with Image.open(io.BytesIO(image_bytes)).convert("RGBA") as image:
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()

        if bbox is None:
            raise RuntimeError("Background removal did not detect a person.")

        left, top, right, bottom = bbox
        width = right - left
        height = bottom - top

        pad_x = max(8, int(width * padding_ratio))
        pad_y = max(8, int(height * padding_ratio))

        left = max(0, left - pad_x)
        top = max(0, top - pad_y)
        right = min(image.width, right + pad_x)
        bottom = min(image.height, bottom + pad_y)

        cropped = image.crop((left, top, right, bottom))
        output = io.BytesIO()
        cropped.save(output, format="PNG", optimize=True)
        return output.getvalue()


def remove_background(image_bytes: bytes) -> bytes:
    """Return a tightly cropped transparent PNG containing the detected person.

    The model runs locally through ONNX Runtime. The model weights are cached
    under backend/models after the first download and are reused for future
    uploads.
    """
    if not image_bytes:
        raise ValueError("Profile photo cannot be empty.")

    from rembg import remove

    output = remove(
        image_bytes,
        session=_get_session(),
        post_process_mask=True,
        force_return_bytes=True,
    )

    if not output:
        raise RuntimeError("Background removal returned an empty image.")

    return crop_transparent_margins(output)

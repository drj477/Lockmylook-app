from __future__ import annotations

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


def remove_background(image_bytes: bytes) -> bytes:
    """Return a transparent PNG containing the detected person only.

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

    return output

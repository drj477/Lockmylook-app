from __future__ import annotations

import hashlib
from pathlib import Path
from uuid import UUID


def build_vto_cache_key(
    *,
    profile_id: UUID,
    person_path: Path,
    garment_paths: list[Path],
    item_ids: list[UUID],
    model: str,
) -> str:
    """Build a deterministic cache key from the exact VTO inputs.

    File contents are included so replacing an uploaded image invalidates the
    old result even when the database item/profile IDs remain unchanged.
    Selected garment order is preserved deliberately.
    """

    hasher = hashlib.sha256()

    def add_text(label: str, value: str) -> None:
        encoded = value.encode("utf-8")
        hasher.update(label.encode("utf-8"))
        hasher.update(len(encoded).to_bytes(8, "big"))
        hasher.update(encoded)

    def add_file(label: str, path: Path) -> None:
        hasher.update(label.encode("utf-8"))
        stat = path.stat()
        hasher.update(stat.st_size.to_bytes(8, "big"))
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                hasher.update(chunk)

    add_text("profile", str(profile_id))
    add_text("model", model)

    for item_id in item_ids:
        add_text("item", str(item_id))

    add_file("person", person_path)

    for index, garment_path in enumerate(garment_paths):
        add_text("garment_index", str(index))
        add_file("garment", garment_path)

    return hasher.hexdigest()

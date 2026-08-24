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
) -> str:
    """Build a deterministic cache key for the visual VTO inputs.

    The model/provider is intentionally NOT part of this key.
    A person + exact garment set should produce one reusable VTO image,
    regardless of which provider generated it first. This lets a later
    request for another model reuse the existing image instead of spending
    another generation credit.

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
    add_text("person", str(person_path.name))
    add_file("person_file", person_path)

    for item_id in item_ids:
        add_text("item", str(item_id))

    for index, garment_path in enumerate(garment_paths):
        add_text("garment_index", str(index))
        add_file("garment", garment_path)

    return hasher.hexdigest()

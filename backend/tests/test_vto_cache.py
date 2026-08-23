from pathlib import Path
from uuid import uuid4

from app.virtual_try_on.cache import build_vto_cache_key


def test_vto_cache_key_is_deterministic(tmp_path: Path):
    person = tmp_path / "person.png"
    garment = tmp_path / "garment.jpg"
    person.write_bytes(b"person-image")
    garment.write_bytes(b"garment-image")

    profile_id = uuid4()
    item_id = uuid4()

    first = build_vto_cache_key(
        profile_id=profile_id,
        person_path=person,
        garment_paths=[garment],
        item_ids=[item_id],
        model="gemini_chat",
    )
    second = build_vto_cache_key(
        profile_id=profile_id,
        person_path=person,
        garment_paths=[garment],
        item_ids=[item_id],
        model="gemini_chat",
    )

    assert first == second
    assert len(first) == 64


def test_vto_cache_key_changes_when_garment_changes(tmp_path: Path):
    person = tmp_path / "person.png"
    garment = tmp_path / "garment.jpg"
    person.write_bytes(b"person-image")
    garment.write_bytes(b"garment-image")

    kwargs = dict(
        profile_id=uuid4(),
        person_path=person,
        garment_paths=[garment],
        item_ids=[uuid4()],
        model="d_tryon",
    )

    original = build_vto_cache_key(**kwargs)
    garment.write_bytes(b"different-garment-image")
    changed = build_vto_cache_key(**kwargs)

    assert original != changed


def test_vto_cache_key_changes_when_model_changes(tmp_path: Path):
    person = tmp_path / "person.png"
    garment = tmp_path / "garment.jpg"
    person.write_bytes(b"person-image")
    garment.write_bytes(b"garment-image")

    base = dict(
        profile_id=uuid4(),
        person_path=person,
        garment_paths=[garment],
        item_ids=[uuid4()],
    )

    gemini = build_vto_cache_key(**base, model="gemini_chat")
    d_tryon = build_vto_cache_key(**base, model="d_tryon")

    assert gemini != d_tryon


def test_vto_cache_key_preserves_garment_order(tmp_path: Path):
    person = tmp_path / "person.png"
    garment_one = tmp_path / "garment1.jpg"
    garment_two = tmp_path / "garment2.jpg"
    person.write_bytes(b"person-image")
    garment_one.write_bytes(b"first")
    garment_two.write_bytes(b"second")

    profile_id = uuid4()
    first_item = uuid4()
    second_item = uuid4()

    ordered = build_vto_cache_key(
        profile_id=profile_id,
        person_path=person,
        garment_paths=[garment_one, garment_two],
        item_ids=[first_item, second_item],
        model="gemini_chat",
    )
    reversed_order = build_vto_cache_key(
        profile_id=profile_id,
        person_path=person,
        garment_paths=[garment_two, garment_one],
        item_ids=[second_item, first_item],
        model="gemini_chat",
    )

    assert ordered != reversed_order

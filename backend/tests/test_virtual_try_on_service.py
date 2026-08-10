from io import BytesIO
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.virtual_try_on.service import VirtualTryOnService


def test_read_output_accepts_file_output_like_object():
    output = BytesIO(b"generated-image")

    assert VirtualTryOnService._read_output(output) == b"generated-image"


def test_read_output_accepts_single_item_list():
    assert VirtualTryOnService._read_output([BytesIO(b"generated-image")]) == b"generated-image"


def test_resolve_local_path_rejects_missing_file(tmp_path, monkeypatch):
    uploads = tmp_path / "uploads"
    uploads.mkdir()
    monkeypatch.chdir(tmp_path)

    with pytest.raises(HTTPException) as error:
        VirtualTryOnService._resolve_local_path("uploads/profiles/missing.jpg")

    assert error.value.status_code == 422


def test_resolve_local_path_rejects_external_file(tmp_path, monkeypatch):
    uploads = tmp_path / "uploads"
    uploads.mkdir()
    outside = tmp_path / "outside.jpg"
    outside.write_bytes(b"image")
    monkeypatch.chdir(tmp_path)

    with pytest.raises(HTTPException) as error:
        VirtualTryOnService._resolve_local_path(str(outside))

    assert error.value.status_code == 422


def test_resolve_local_path_accepts_upload(tmp_path, monkeypatch):
    uploads = tmp_path / "uploads" / "profiles"
    uploads.mkdir(parents=True)
    image = uploads / f"{uuid4()}.jpg"
    image.write_bytes(b"image")
    monkeypatch.chdir(tmp_path)

    resolved = VirtualTryOnService._resolve_local_path(
        image.relative_to(tmp_path).as_posix()
    )

    assert resolved == Path(image).resolve()


def test_resolve_local_path_rejects_remote_reference():
    with pytest.raises(HTTPException) as error:
        VirtualTryOnService._resolve_local_path("https://example.com/person.jpg")

    assert error.value.status_code == 422

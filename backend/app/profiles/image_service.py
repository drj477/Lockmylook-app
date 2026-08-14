from pathlib import Path

from fastapi import UploadFile
from sqlmodel import Session

from app.profiles.background_removal import (
    crop_transparent_margins,
    remove_background,
)
from app.profiles.model import Profile

UPLOAD_DIR = Path("uploads/profiles")
MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class ProfileImageService:
    def upload(
        self,
        session: Session,
        profile: Profile,
        file: UploadFile,
    ) -> Profile:
        extension = ALLOWED_CONTENT_TYPES.get(file.content_type or "")
        if extension is None:
            raise ValueError("Profile photo must be JPEG, PNG, or WebP.")

        data = file.file.read(MAX_FILE_SIZE + 1)
        if len(data) > MAX_FILE_SIZE:
            raise ValueError("Profile photo must be 10 MB or smaller.")
        if not data:
            raise ValueError("Profile photo cannot be empty.")

        old_paths = self._stored_paths(profile)
        filepath = UPLOAD_DIR / f"{profile.id}{extension}"
        vto_path = UPLOAD_DIR / f"{profile.id}-vto.png"

        try:
            # Generate the VTO asset before committing the new profile record.
            # This guarantees that a successful profile upload always has a
            # usable transparent person asset for future VTO requests.
            vto_data = remove_background(data)
            filepath.write_bytes(data)
            vto_path.write_bytes(vto_data)
        except Exception as error:
            filepath.unlink(missing_ok=True)
            vto_path.unlink(missing_ok=True)
            raise ValueError(
                "Profile photo was saved locally but could not be processed "
                "for Virtual Try-On."
            ) from error

        for old_path in old_paths:
            if old_path not in {filepath.resolve(), vto_path.resolve()}:
                old_path.unlink(missing_ok=True)

        profile.avatar_url = str(filepath)
        profile.vto_asset_url = str(vto_path)
        session.add(profile)
        session.commit()
        session.refresh(profile)
        return profile

    def ensure_vto_asset(self, session: Session, profile: Profile) -> Profile:
        """Ensure an older profile has a tightly cropped VTO asset."""
        if profile.vto_asset_url:
            path = Path(profile.vto_asset_url)
            if not path.is_absolute():
                path = Path.cwd() / path
            path = path.resolve()

            if path.exists() and path.is_file() and path.stat().st_size > 0:
                try:
                    cropped = crop_transparent_margins(path.read_bytes())
                    path.write_bytes(cropped)
                    profile.vto_asset_url = str(path)
                    session.add(profile)
                    session.commit()
                    session.refresh(profile)
                    return profile
                except Exception:
                    # Fall through and rebuild from the original profile image.
                    pass

        if not profile.avatar_url:
            raise ValueError("Add a profile image before using Virtual Try-On.")

        source_path = Path(profile.avatar_url)
        if not source_path.is_absolute():
            source_path = Path.cwd() / source_path
        source_path = source_path.resolve()

        uploads_root = (Path.cwd() / "uploads").resolve()
        try:
            source_path.relative_to(uploads_root)
        except ValueError as error:
            raise ValueError("Profile image is outside the application's uploads directory.") from error

        if not source_path.exists() or not source_path.is_file():
            raise ValueError("Profile image file is unavailable.")

        vto_path = UPLOAD_DIR / f"{profile.id}-vto.png"
        try:
            vto_path.write_bytes(remove_background(source_path.read_bytes()))
        except Exception as error:
            vto_path.unlink(missing_ok=True)
            raise ValueError("Existing profile image could not be processed for Virtual Try-On.") from error

        profile.vto_asset_url = str(vto_path)
        session.add(profile)
        session.commit()
        session.refresh(profile)
        return profile

    def delete(self, session: Session, profile: Profile) -> None:
        for path in self._stored_paths(profile):
            path.unlink(missing_ok=True)

        profile.avatar_url = None
        profile.vto_asset_url = None
        session.add(profile)
        session.commit()

    @staticmethod
    def _stored_paths(profile: Profile) -> set[Path]:
        paths: set[Path] = set()
        for value in (profile.avatar_url, profile.vto_asset_url):
            if not value:
                continue
            path = Path(value)
            if not path.is_absolute():
                path = Path.cwd() / path
            paths.add(path.resolve())
        return paths


profile_image_service = ProfileImageService()

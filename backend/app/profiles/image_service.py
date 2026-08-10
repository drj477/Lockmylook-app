from pathlib import Path

from fastapi import UploadFile
from sqlmodel import Session

from app.profiles.background_removal import remove_background
from app.profiles.model import Profile

PROFILE_UPLOAD_DIR = Path("uploads/profiles")
VTO_UPLOAD_DIR = Path("uploads/vto_profiles")
MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

PROFILE_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
VTO_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


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

        old_paths = self.stored_paths(profile)
        filepath = PROFILE_UPLOAD_DIR / f"{profile.id}{extension}"
        vto_path = VTO_UPLOAD_DIR / f"{profile.id}.png"

        try:
            # Keep the original profile image untouched. The VTO asset is a
            # separate transparent derivative used only by the try-on pipeline.
            vto_data = remove_background(data)
            filepath.write_bytes(data)
            vto_path.write_bytes(vto_data)
        except Exception as error:
            filepath.unlink(missing_ok=True)
            vto_path.unlink(missing_ok=True)
            raise ValueError(
                "Profile photo could not be processed for Virtual Try-On."
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
        """Create/migrate the VTO asset for an older profile."""
        if profile.vto_asset_url:
            existing = self._path_from_value(profile.vto_asset_url)
            if existing and existing.exists() and existing.is_file() and existing.stat().st_size > 0:
                # Older builds stored VTO files beside profile photos. Move the
                # derivative to the dedicated VTO directory on first use.
                if VTO_UPLOAD_DIR.resolve() in existing.parents:
                    return profile

        if not profile.avatar_url:
            raise ValueError("Add a profile image before using Virtual Try-On.")

        source_path = self._path_from_value(profile.avatar_url)
        if source_path is None:
            raise ValueError("Profile image is unavailable.")

        uploads_root = (Path.cwd() / "uploads").resolve()
        try:
            source_path.relative_to(uploads_root)
        except ValueError as error:
            raise ValueError(
                "Profile image is outside the application's uploads directory."
            ) from error

        if not source_path.exists() or not source_path.is_file():
            raise ValueError("Profile image file is unavailable.")

        vto_path = VTO_UPLOAD_DIR / f"{profile.id}.png"
        old_vto_path = self._path_from_value(profile.vto_asset_url)

        try:
            vto_path.write_bytes(remove_background(source_path.read_bytes()))
        except Exception as error:
            vto_path.unlink(missing_ok=True)
            raise ValueError(
                "Existing profile image could not be processed for Virtual Try-On."
            ) from error

        profile.vto_asset_url = str(vto_path)
        session.add(profile)
        session.commit()
        session.refresh(profile)

        if old_vto_path and old_vto_path != vto_path.resolve():
            old_vto_path.unlink(missing_ok=True)

        return profile

    def delete(self, session: Session, profile: Profile) -> None:
        for path in self.stored_paths(profile):
            path.unlink(missing_ok=True)

        profile.avatar_url = None
        profile.vto_asset_url = None
        session.add(profile)
        session.commit()

    @staticmethod
    def _path_from_value(value: str | None) -> Path | None:
        if not value:
            return None
        path = Path(value)
        if not path.is_absolute():
            path = Path.cwd() / path
        return path.resolve()

    @classmethod
    def stored_paths(cls, profile: Profile) -> set[Path]:
        paths: set[Path] = set()
        for value in (profile.avatar_url, profile.vto_asset_url):
            path = cls._path_from_value(value)
            if path:
                paths.add(path)
        return paths


profile_image_service = ProfileImageService()

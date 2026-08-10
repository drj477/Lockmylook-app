from pathlib import Path

from fastapi import UploadFile
from sqlmodel import Session

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

        for old_extension in ALLOWED_CONTENT_TYPES.values():
            old_path = UPLOAD_DIR / f"{profile.id}{old_extension}"
            if old_path.exists():
                old_path.unlink()

        filepath = UPLOAD_DIR / f"{profile.id}{extension}"
        filepath.write_bytes(data)

        profile.avatar_url = str(filepath)
        session.add(profile)
        session.commit()
        session.refresh(profile)
        return profile

    def delete(self, session: Session, profile: Profile) -> None:
        if profile.avatar_url:
            path = Path(profile.avatar_url)
            if path.exists():
                path.unlink()

        profile.avatar_url = None
        session.add(profile)
        session.commit()


profile_image_service = ProfileImageService()

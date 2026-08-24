from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import HTTPException
from loguru import logger
from PIL import Image
from replicate.exceptions import ModelError
from sqlmodel import Session, select

from app.core.config import get_settings
from app.credits.model import CreditTransactionType
from app.credits.service import debit, generation_cost_units, refund_generation
from app.profiles.image_service import profile_image_service
from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem

from .cache import build_vto_cache_key
from .d_tryon_provider import DTryOnVirtualTryOnProvider
from .gemini_chat.client import (
    GeminiChatAuthenticationError,
    GeminiChatConfigurationError,
)
from .gemini_chat.provider import GeminiChatVirtualTryOnProvider
from .model import VirtualTryOnModel, VirtualTryOnResult
from .providers import (
    GeminiVirtualTryOnProvider,
    ReplicateVirtualTryOnProvider,
    VirtualTryOnProvider,
)


class VirtualTryOnService:
    """Generate and persist virtual try-on results through selectable providers."""

    MAX_GARMENTS = 4

    def __init__(self) -> None:
        self._gemini_chat_provider: GeminiChatVirtualTryOnProvider | None = None

    async def generate(
        self,
        session: Session,
        profile: Profile,
        items: list[WardrobeItem],
        account_id: UUID,
        model: VirtualTryOnModel = VirtualTryOnModel.REPLICATE,
    ) -> VirtualTryOnResult:
        settings = get_settings()

        if not profile.avatar_url:
            raise HTTPException(
                status_code=422,
                detail="Add a profile image before using Virtual Try-On.",
            )

        if not items:
            raise HTTPException(
                status_code=422,
                detail="Select at least one wardrobe item before using Virtual Try-On.",
            )

        if len(items) > self.MAX_GARMENTS:
            raise HTTPException(
                status_code=422,
                detail=(
                    f"Virtual Try-On currently supports up to "
                    f"{self.MAX_GARMENTS} garments per request."
                ),
            )

        if not profile.vto_asset_url:
            try:
                profile = profile_image_service.ensure_vto_asset(session, profile)
            except ValueError as error:
                raise HTTPException(status_code=422, detail=str(error)) from error

        person_path = self._resolve_local_path(profile.vto_asset_url)
        garment_paths: list[Path] = []
        garment_names: list[str] = []
        item_ids = [item.id for item in items]

        for item in items:
            if not item.images:
                raise HTTPException(
                    status_code=422,
                    detail=f'Add an image to "{item.name}" before trying it on.',
                )

            image = sorted(item.images, key=lambda value: value.display_order)[0]
            garment_paths.append(self._resolve_local_path(image.image_url))
            garment_names.append(item.name)

        # The cache represents the visual request, not the provider. All VTO
        # models therefore reuse the same generated image for the same inputs.
        cache_key = build_vto_cache_key(
            profile_id=profile.id,
            person_path=person_path,
            garment_paths=garment_paths,
            item_ids=item_ids,
        )

        cached_result = session.exec(
            select(VirtualTryOnResult).where(
                VirtualTryOnResult.profile_id == profile.id,
                VirtualTryOnResult.cache_key == cache_key,
            )
        ).first()

        if cached_result is not None:
            logger.info(
                "Virtual Try-On cache hit: profile={} result={} requested_model={} generated_model={} hash={}",
                profile.id,
                cached_result.id,
                model.value,
                cached_result.model,
                cache_key,
            )
            debit(
                session,
                account_id=account_id,
                units=generation_cost_units(model.value, cache_hit=True),
                transaction_type=CreditTransactionType.CACHE_HIT,
                reason="Virtual try-on cache hit",
                provider=model.value,
                vto_result_id=cached_result.id,
            )
            return cached_result

        logger.info(
            "Virtual Try-On cache miss: profile={} requested_model={} hash={}",
            profile.id,
            model.value,
            cache_key,
        )

        prompt = self._build_prompt(garment_names)
        provider = self._provider(model, settings)
        generation_units = generation_cost_units(model.value, cache_hit=False)

        debit(
            session,
            account_id=account_id,
            units=generation_units,
            transaction_type=CreditTransactionType.GENERATION,
            reason="Virtual try-on generation",
            provider=model.value,
        )
        charged_units = generation_units

        def refund_if_charged() -> None:
            nonlocal charged_units
            if charged_units <= 0:
                return
            try:
                refund_generation(
                    session,
                    account_id=account_id,
                    units=charged_units,
                    provider=model.value,
                )
                charged_units = 0
            except Exception:
                logger.exception(
                    "Failed to refund VTO credits: account={} model={} units={}",
                    account_id,
                    model.value,
                    charged_units,
                )

        logger.info(
            "Starting Virtual Try-On: profile={} garments={} model={} person_asset={} credit_units={}",
            profile.id,
            garment_names,
            model.value,
            person_path,
            generation_units,
        )

        try:
            output_bytes = await provider.generate(
                person_path=person_path,
                garment_paths=garment_paths,
                garment_names=garment_names,
                prompt=prompt,
            )
        except ModelError as error:
            refund_if_charged()
            prediction = getattr(error, "prediction", None)
            prediction_id = getattr(prediction, "id", None)
            prediction_status = getattr(prediction, "status", None)
            prediction_error = getattr(prediction, "error", None)
            prediction_logs = getattr(prediction, "logs", None)
            logger.error(
                "Replicate VTO failed: prediction_id={} status={} error={} logs={}",
                prediction_id,
                prediction_status,
                prediction_error,
                prediction_logs,
            )
            detail = prediction_error or str(error)
            if prediction_id:
                detail = f"{detail} (prediction: {prediction_id})"
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On provider error: {detail}",
            ) from error
        except GeminiChatConfigurationError as error:
            refund_if_charged()
            raise HTTPException(
                status_code=503,
                detail="Gemini Chat is not configured. Set GEMINI_CHAT_COOKIE_JSON on the backend.",
            ) from error
        except GeminiChatAuthenticationError as error:
            refund_if_charged()
            raise HTTPException(
                status_code=503,
                detail=(
                    "Gemini Chat authentication has expired. Re-export the Gemini browser "
                    "cookies and update the server-side cookie JSON."
                ),
            ) from error
        except RuntimeError as error:
            refund_if_charged()
            detail = str(error)
            if "GEMINI_API_KEY" in detail:
                raise HTTPException(
                    status_code=503,
                    detail="Gemini Virtual Try-On is not configured. Add GEMINI_API_KEY to backend/.env.",
                ) from error
            if "REPLICATE_API_TOKEN" in detail:
                raise HTTPException(
                    status_code=503,
                    detail="Replicate Virtual Try-On is not configured. Add REPLICATE_API_TOKEN to backend/.env.",
                ) from error
            if "PRUNA_API_KEY" in detail or "PRUNA_PUBLIC_BASE_URL" in detail:
                raise HTTPException(status_code=503, detail=detail) from error
            logger.exception(
                "Virtual Try-On provider failed: profile={} model={}",
                profile.id,
                model.value,
            )
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On provider error: {detail}",
            ) from error
        except HTTPException:
            refund_if_charged()
            raise
        except Exception as error:
            refund_if_charged()
            logger.exception(
                "Unexpected Virtual Try-On failure: profile={} model={}",
                profile.id,
                model.value,
            )
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On failed while processing the images: {error}",
            ) from error

        if not output_bytes:
            refund_if_charged()
            raise HTTPException(
                status_code=502,
                detail="Virtual Try-On completed without returning an image.",
            )

        try:
            output_bytes = self._normalize_output(output_bytes)
            output_dir = Path("uploads/tryon")
            output_dir.mkdir(parents=True, exist_ok=True)
            filename = f"{profile.id}-{uuid4()}.webp"
            output_path = output_dir / filename
            output_path.write_bytes(output_bytes)

            result = VirtualTryOnResult(
                profile_id=profile.id,
                image_url=f"/uploads/tryon/{filename}",
                item_ids_json=json.dumps([str(item.id) for item in items]),
                model=model.value,
                cache_key=cache_key,
            )
            session.add(result)
            session.commit()
            session.refresh(result)
            charged_units = 0
        except Exception as error:
            refund_if_charged()
            logger.exception(
                "Virtual Try-On result persistence failed: profile={} model={}",
                profile.id,
                model.value,
            )
            raise HTTPException(
                status_code=502,
                detail=f"Virtual Try-On failed while saving the generated image: {error}",
            ) from error

        logger.info(
            "Virtual Try-On completed: profile={} result={} generated_model={} path={} hash={}",
            profile.id,
            result.id,
            model.value,
            output_path,
            cache_key,
        )
        return result

    def _provider(self, model: VirtualTryOnModel, settings) -> VirtualTryOnProvider:
        if model is VirtualTryOnModel.REPLICATE:
            return ReplicateVirtualTryOnProvider(settings)
        if model is VirtualTryOnModel.GEMINI:
            return GeminiVirtualTryOnProvider(settings)
        if model is VirtualTryOnModel.GEMINI_CHAT:
            if self._gemini_chat_provider is None:
                self._gemini_chat_provider = GeminiChatVirtualTryOnProvider(settings)
            return self._gemini_chat_provider
        if model is VirtualTryOnModel.D_TRYON:
            return DTryOnVirtualTryOnProvider(settings)
        raise HTTPException(status_code=422, detail=f"Unsupported Virtual Try-On model: {model}")

    @staticmethod
    def _resolve_local_path(value: str) -> Path:
        """Resolve a local upload path and reject unsafe/nonexistent references."""
        if not value or "://" in value:
            raise HTTPException(status_code=422, detail="Invalid local image reference.")

        raw_path = Path(value)
        if raw_path.is_absolute():
            path = raw_path.resolve()
        else:
            path = (Path.cwd() / raw_path).resolve()

        uploads_root = (Path.cwd() / "uploads").resolve()
        try:
            path.relative_to(uploads_root)
        except ValueError as error:
            raise HTTPException(
                status_code=422,
                detail="Image reference must point to a local upload.",
            ) from error

        if not path.exists() or not path.is_file():
            raise HTTPException(
                status_code=422,
                detail="Referenced image file was not found.",
            )

        return path

    @staticmethod
    def _read_output(output: object) -> bytes:
        """Read provider output from bytes, a file-like object, or one-item list."""
        if isinstance(output, (bytes, bytearray)):
            return bytes(output)

        if isinstance(output, list):
            if len(output) != 1:
                raise ValueError("Expected exactly one provider output.")
            return VirtualTryOnService._read_output(output[0])

        reader = getattr(output, "read", None)
        if callable(reader):
            value = reader()
            if not isinstance(value, (bytes, bytearray)):
                raise ValueError("Provider output read() must return bytes.")
            return bytes(value)

        raise ValueError("Unsupported provider output type.")

    @staticmethod
    def _normalize_output(output_bytes: bytes) -> bytes:
        with Image.open(BytesIO(output_bytes)) as image:
            if image.mode not in ("RGB", "RGBA"):
                image = image.convert("RGBA")
            output = BytesIO()
            image.save(output, format="WEBP", quality=95)
            return output.getvalue()

    @staticmethod
    def _build_prompt(garment_names: list[str]) -> str:
        garment_lines = "\n".join(
            f"- Reference garment image {index + 2}: {name}"
            for index, name in enumerate(garment_names)
        )
        return f"""Create a photorealistic virtual try-on photograph.

REFERENCE IMAGE 1 is the PERSON. It is authoritative for identity, face, hair,
body proportions, pose, hands, skin, lower body and the original scene.

The remaining reference images are the GARMENTS. Transfer those exact garments
onto the person. Each garment reference is authoritative for its visual design.

{garment_lines}

STRICT REQUIREMENTS:

- Preserve the person's identity exactly. Do not regenerate or reinterpret the face.
- Preserve facial structure, hair, skin tone, body proportions and age appearance.
- Preserve the original pose, hands, arms, legs and feet.
- Preserve the original camera perspective and composition.
- Preserve the original background unless a natural adjustment is required for lighting.
- Change clothing only.
- Use the garment references as exact visual references, not inspiration.
- Preserve exact garment color, pattern, print, material, texture, construction and proportions.
- Preserve collars, necklines, buttons, zippers, pockets, seams, cuffs and hems.
- Preserve the complete sleeve length and sleeve construction. Never shorten, remove or crop sleeves.
- Fit each garment naturally to the person's actual body and pose.
- Create realistic fabric folds, tension, occlusion and shadows caused by the pose.
- Keep hands naturally in front of or beside the garments when appropriate.
- Do not add accessories or change unrelated clothing.
- Do not redesign, simplify or invent garment details.
- Do not change the person's gender, hairstyle, facial expression or body shape.
- Do not add accessories or garments that were not selected.
- The result must look like a real photograph of the same person wearing the supplied garments.
- Keep the output image aspect ratio 3:4. The ratio is Width:Height.

Output only the finished image."""

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

        # Reserve the generation cost before calling an external provider. If
        # generation fails, the exact reservation is refunded below.
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
        path = Path(value)
        if not path.is_absolute():
            path = Path.cwd() / path
        return path.resolve()

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
        garments = ", ".join(garment_names)
        return (
            "Create a realistic virtual try-on image. Preserve the person's identity, "
            "body proportions, pose, hair, skin tone, and overall appearance. Replace "
            f"the clothing with the selected wardrobe items: {garments}. "
            "Fit the garments naturally and accurately. Keep the full person visible. "
            "Do not add accessories or garments that were not selected."
        )

    def to_response(self, result: VirtualTryOnResult, base_url: str) -> dict:
        image_url = result.image_url
        if image_url.startswith("/"):
            image_url = f"{base_url.rstrip('/')}{image_url}"
        return {
            "id": result.id,
            "profile_id": result.profile_id,
            "image_url": image_url,
            "item_ids": json.loads(result.item_ids_json),
            "model": result.model,
            "created_at": result.created_at,
            "saved": result.saved,
        }

    def set_saved(
        self,
        session: Session,
        profile: Profile,
        result_id: UUID,
        saved: bool,
    ) -> dict:
        result = session.exec(
            select(VirtualTryOnResult).where(
                VirtualTryOnResult.id == result_id,
                VirtualTryOnResult.profile_id == profile.id,
            )
        ).first()
        if result is None:
            raise HTTPException(status_code=404, detail="Virtual Try-On result not found.")

        result.saved = saved
        session.add(result)
        session.commit()
        session.refresh(result)
        return {"id": result.id, "saved": result.saved}

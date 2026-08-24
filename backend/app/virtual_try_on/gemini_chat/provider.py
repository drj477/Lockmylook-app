from __future__ import annotations

from pathlib import Path

from app.core.config import Settings

from .client import GeminiChatClient


class GeminiChatVirtualTryOnProvider:
    """Gemini Web API VTO provider with a Gemini-specific fidelity prompt."""

    def __init__(self, settings: Settings) -> None:
        self._client = GeminiChatClient(settings)

    async def generate(
        self,
        *,
        person_path: Path,
        garment_paths: list[Path],
        garment_names: list[str],
        prompt: str,
    ) -> bytes:
        # The shared service prompt is intentionally ignored here.
        # Gemini Chat has its own detailed image-editing prompt so changes to
        # this provider cannot affect D-Tryon, Replicate, or Gemini API VTO.
        del prompt

        gemini_prompt = self._build_prompt(garment_names)

        return await self._client.generate_try_on(
            person_path=person_path,
            garment_paths=garment_paths,
            prompt=gemini_prompt,
        )

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

    async def close(self) -> None:
        await self._client.close()


__all__ = ["GeminiChatVirtualTryOnProvider"]

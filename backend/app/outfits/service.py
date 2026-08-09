from itertools import product

from sqlmodel import Session

from app.profiles.model import Profile
from app.wardrobe.model import WardrobeItem
from app.wardrobe.queries import WardrobeQueries

from .schema import (
    OutfitGenerateRequest,
    OutfitGenerateResponse,
    OutfitItemResponse,
    OutfitSuggestionResponse,
)


class OutfitService:
    """Deterministic rule-based outfit generator."""

    _TOP_CATEGORIES = {
        "top",
        "tops",
        "shirt",
        "shirts",
        "t-shirt",
        "t-shirts",
        "blouse",
        "blouses",
    }

    _BOTTOM_CATEGORIES = {
        "bottom",
        "bottoms",
        "pants",
        "trousers",
        "jeans",
        "shorts",
        "skirts",
    }

    _ONE_PIECE_CATEGORIES = {
        "dress",
        "dresses",
        "jumpsuit",
        "jumpsuits",
        "dresses & jumpsuits",
    }

    _FOOTWEAR_CATEGORIES = {
        "footwear",
        "shoe",
        "shoes",
        "sneakers",
        "boots",
        "sandals",
        "heels",
    }

    _OUTERWEAR_CATEGORIES = {
        "outerwear",
        "jacket",
        "jackets",
        "coat",
        "coats",
        "blazer",
        "blazers",
        "cardigan",
        "cardigans",
    }

    def __init__(self) -> None:
        self._wardrobe_queries = WardrobeQueries()

    def generate(
        self,
        session: Session,
        profile: Profile,
        payload: OutfitGenerateRequest,
    ) -> OutfitGenerateResponse:
        items = self._wardrobe_queries.list_items(
            session=session,
            profile=profile,
        )

        filtered_items = self._filter_items(
            items=items,
            payload=payload,
        )

        suggestions = self._build_suggestions(
            items=filtered_items,
            payload=payload,
        )

        return OutfitGenerateResponse(
            occasion=payload.occasion,
            season=payload.season,
            mood=payload.mood,
            suggestions=suggestions[: payload.limit],
        )

    def _filter_items(
        self,
        items: list[WardrobeItem],
        payload: OutfitGenerateRequest,
    ) -> list[WardrobeItem]:
        occasion = self._normalize(payload.occasion)
        season = self._normalize(payload.season)

        filtered: list[WardrobeItem] = []

        for item in items:
            item_occasion = self._normalize(item.occasion)
            item_season = self._normalize(item.season)

            if (
                item_occasion
                and occasion
                and occasion not in item_occasion
                and item_occasion not in occasion
                and "all" not in item_occasion
                and "any" not in item_occasion
            ):
                continue

            if (
                season
                and item_season
                and season not in item_season
                and item_season not in season
                and "all" not in item_season
                and "any" not in item_season
            ):
                continue

            filtered.append(item)

        return filtered

    def _build_suggestions(
        self,
        items: list[WardrobeItem],
        payload: OutfitGenerateRequest,
    ) -> list[OutfitSuggestionResponse]:
        tops = [item for item in items if self._category(item) in self._TOP_CATEGORIES]

        bottoms = [item for item in items if self._category(item) in self._BOTTOM_CATEGORIES]

        one_piece = [item for item in items if self._category(item) in self._ONE_PIECE_CATEGORIES]

        footwear = [item for item in items if self._category(item) in self._FOOTWEAR_CATEGORIES]

        outerwear = [item for item in items if self._category(item) in self._OUTERWEAR_CATEGORIES]

        suggestions: list[OutfitSuggestionResponse] = []

        # Standard outfit: top + bottom + footwear.
        for top, bottom, shoe in product(
            tops,
            bottoms,
            footwear,
        ):
            items_for_outfit = [top, bottom, shoe]

            score = self._score_outfit(
                items=items_for_outfit,
                payload=payload,
            )

            suggestions.append(
                self._make_suggestion(
                    items=items_for_outfit,
                    score=score,
                    payload=payload,
                )
            )

            for layer in outerwear:
                layered_items = [
                    top,
                    bottom,
                    shoe,
                    layer,
                ]

                layered_score = self._score_outfit(
                    items=layered_items,
                    payload=payload,
                )

                suggestions.append(
                    self._make_suggestion(
                        items=layered_items,
                        score=layered_score,
                        payload=payload,
                    )
                )

        # One-piece outfit: dress/jumpsuit + footwear.
        for piece, shoe in product(
            one_piece,
            footwear,
        ):
            items_for_outfit = [piece, shoe]

            score = self._score_outfit(
                items=items_for_outfit,
                payload=payload,
            )

            suggestions.append(
                self._make_suggestion(
                    items=items_for_outfit,
                    score=score,
                    payload=payload,
                )
            )

        suggestions.sort(
            key=lambda suggestion: suggestion.score,
            reverse=True,
        )

        return self._deduplicate_suggestions(suggestions)

    def _score_outfit(
        self,
        items: list[WardrobeItem],
        payload: OutfitGenerateRequest,
    ) -> float:
        score = 50.0

        # Favorite items receive a small boost.
        score += sum(5.0 for item in items if item.favorite)

        # Matching season.
        if payload.season:
            requested_season = self._normalize(payload.season)

            for item in items:
                item_season = self._normalize(item.season)

                if item_season and requested_season in item_season:
                    score += 8.0

        # Matching occasion.
        requested_occasion = self._normalize(payload.occasion)

        for item in items:
            item_occasion = self._normalize(item.occasion)

            if item_occasion and requested_occasion in item_occasion:
                score += 10.0

        # Basic color compatibility.
        colors = [self._normalize(item.primary_color) for item in items if item.primary_color]

        colors = [color for color in colors if color]

        unique_colors = set(colors)

        if len(unique_colors) == 1:
            score += 5.0
        elif len(unique_colors) <= 2:
            score += 8.0

        # Lightweight mood preference.
        if payload.mood:
            mood = self._normalize(payload.mood)

            if (
                mood
                in {
                    "minimal",
                    "classic",
                    "clean",
                }
                and len(unique_colors) <= 2
            ):
                score += 5.0

            elif (
                mood
                in {
                    "bold",
                    "experimental",
                }
                and len(unique_colors) >= 2
            ):
                score += 4.0

        return round(score, 2)

    def _make_suggestion(
        self,
        items: list[WardrobeItem],
        score: float,
        payload: OutfitGenerateRequest,
    ) -> OutfitSuggestionResponse:
        reason_parts = [f"Built for {payload.occasion}."]

        if payload.season:
            reason_parts.append(f"Matches the {payload.season} season.")

        if any(item.favorite for item in items):
            reason_parts.append("Includes favorite wardrobe pieces.")

        return OutfitSuggestionResponse(
            id="-".join(str(item.id) for item in items),
            score=score,
            reason=" ".join(reason_parts),
            items=[self._item_response(item) for item in items],
        )

    def _item_response(
        self,
        item: WardrobeItem,
    ) -> OutfitItemResponse:
        image_url = None

        if item.images:
            ordered_images = sorted(
                item.images,
                key=lambda image: image.display_order,
            )

            image_url = ordered_images[0].thumbnail_url

        return OutfitItemResponse(
            id=item.id,
            name=item.name,
            brand=item.brand,
            category=item.category.name,
            primary_color=item.primary_color,
            secondary_color=item.secondary_color,
            season=item.season,
            occasion=item.occasion,
            favorite=item.favorite,
            image_url=image_url,
        )

    def _category(
        self,
        item: WardrobeItem,
    ) -> str:
        return self._normalize(item.category.name)

    @staticmethod
    def _normalize(
        value: str | None,
    ) -> str:
        if not value:
            return ""

        return " ".join(value.lower().strip().split())

    @staticmethod
    def _deduplicate_suggestions(
        suggestions: list[OutfitSuggestionResponse],
    ) -> list[OutfitSuggestionResponse]:
        seen: set[str] = set()
        unique: list[OutfitSuggestionResponse] = []

        for suggestion in suggestions:
            item_ids = tuple(sorted(str(item.id) for item in suggestion.items))

            key = "|".join(item_ids)

            if key in seen:
                continue

            seen.add(key)
            unique.append(suggestion)

        return unique

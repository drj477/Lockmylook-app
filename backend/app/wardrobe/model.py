from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlmodel import Field, Relationship, SQLModel


class WardrobeCategory(SQLModel, table=True):
    __tablename__ = "wardrobe_categories"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str = Field(index=True, unique=True, nullable=False)
    is_system: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))

    items: list["WardrobeItem"] = Relationship(back_populates="category")


class WardrobeItem(SQLModel, table=True):
    __tablename__ = "wardrobe_items"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    profile_id: UUID = Field(foreign_key="profiles.id", nullable=False, index=True)
    category_id: UUID = Field(foreign_key="wardrobe_categories.id", nullable=False, index=True)
    name: str = Field(max_length=100)
    brand: str | None = Field(default=None, max_length=100)
    primary_color: str | None = None
    secondary_color: str | None = None
    season: str | None = None
    occasion: str | None = None
    favorite: bool = Field(default=False)
    is_deleted: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))

    category: WardrobeCategory = Relationship(back_populates="items")
    images: list["WardrobeImage"] = Relationship(back_populates="item")


class WardrobeImage(SQLModel, table=True):
    __tablename__ = "wardrobe_images"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    wardrobe_item_id: UUID = Field(foreign_key="wardrobe_items.id", nullable=False, index=True)
    image_url: str
    thumbnail_url: str
    original_image_url: str | None = None
    background_removed: bool = Field(default=False)
    display_order: int = Field(default=0)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))

    item: WardrobeItem = Relationship(back_populates="images")

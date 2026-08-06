from sqlmodel import Session, select

from app.database.session import engine
from app.wardrobe.model import WardrobeCategory

SYSTEM_CATEGORIES = [
    "Tops",
    "Bottoms",
    "Dresses & Jumpsuits",
    "Outerwear",
    "Footwear",
    "Bags",
    "Accessories",
    "Headwear",
    "Socks & Hosiery",
    "Innerwear",
    "Sleepwear",
    "Activewear & Swimwear",
    "Formal Wear",
    "Ethnic Wear",
]


def seed_categories() -> None:
    with Session(engine) as session:

        for name in SYSTEM_CATEGORIES:

            existing = session.exec(
                select(WardrobeCategory).where(
                    WardrobeCategory.name == name
                )
            ).first()

            if existing:
                existing.is_system = True
            else:
                session.add(
                    WardrobeCategory(
                        name=name,
                        is_system=True,
                    )
                )

        session.commit()

    print("✅ System categories seeded.")


if __name__ == "__main__":
    seed_categories()
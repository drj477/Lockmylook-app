from dataclasses import dataclass


@dataclass(frozen=True)
class CreditPackage:
    code: str
    name: str
    credits: int
    amount_paise: int
    description: str


CREDIT_PACKAGES: tuple[CreditPackage, ...] = (
    CreditPackage("basic", "Basic", 10, 5000, "A quick credit boost"),
    CreditPackage("starter", "Starter", 20, 10000, "For occasional try-ons"),
    CreditPackage("standard", "Standard", 50, 25000, "For regular styling"),
    CreditPackage("pro", "Pro", 100, 50000, "For heavy styling use"),
)

_PACKAGES_BY_CODE = {package.code: package for package in CREDIT_PACKAGES}


def get_credit_package(code: str) -> CreditPackage | None:
    return _PACKAGES_BY_CODE.get(code)

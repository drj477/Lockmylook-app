from dataclasses import dataclass


@dataclass(frozen=True)
class CreditPackage:
    code: str
    name: str
    credits: int
    amount_paise: int


CREDIT_PACKAGES: tuple[CreditPackage, ...] = (
    CreditPackage(code="basic", name="Basic", credits=10, amount_paise=5000),
    CreditPackage(code="starter", name="Starter", credits=20, amount_paise=10000),
    CreditPackage(code="standard", name="Standard", credits=50, amount_paise=25000),
    CreditPackage(code="pro", name="Pro", credits=100, amount_paise=50000),
)


_PACKAGES_BY_CODE = {package.code: package for package in CREDIT_PACKAGES}


def get_credit_package(code: str) -> CreditPackage | None:
    return _PACKAGES_BY_CODE.get(code)

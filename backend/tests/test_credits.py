from app.credits.service import (
    CACHE_HIT_UNITS,
    CREDIT_RUPEES,
    GEMINI_CHAT_UNITS,
    PAID_GENERATION_UNITS,
    UNITS_PER_CREDIT,
    generation_cost_units,
)


def test_credit_pricing_contract() -> None:
    assert CREDIT_RUPEES == 5
    assert UNITS_PER_CREDIT == 2
    assert PAID_GENERATION_UNITS == 4
    assert GEMINI_CHAT_UNITS == 2
    assert CACHE_HIT_UNITS == 1


def test_generation_costs_use_half_credit_units() -> None:
    assert generation_cost_units("d_tryon", cache_hit=False) == 4
    assert generation_cost_units("replicate", cache_hit=False) == 4
    assert generation_cost_units("gemini", cache_hit=False) == 4
    assert generation_cost_units("gemini_chat", cache_hit=False) == 2
    assert generation_cost_units("d_tryon", cache_hit=True) == 1
    assert generation_cost_units("gemini_chat", cache_hit=True) == 1

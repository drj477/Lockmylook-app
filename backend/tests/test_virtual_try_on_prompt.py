from app.virtual_try_on.service import VirtualTryOnService


def test_try_on_prompt_explicitly_preserves_sleeves_and_identity():
    prompt = VirtualTryOnService._build_prompt(["Blue Checkered Shirt"])

    assert "Preserve the person's identity exactly" in prompt
    assert "complete sleeve length" in prompt
    assert "Never shorten, remove or crop sleeves" in prompt
    assert "Blue Checkered Shirt" in prompt

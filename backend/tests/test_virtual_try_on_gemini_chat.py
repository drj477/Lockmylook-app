import pytest

from app.virtual_try_on.gemini_chat.client import (
    GeminiChatClient,
    GeminiChatConfigurationError,
)


def test_gemini_chat_cookie_loader_accepts_exported_dict(tmp_path):
    cookie_file = tmp_path / "gemini-cookies.json"
    cookie_file.write_text(
        '{"cookies": {"__Secure-1PSID": "psid", "__Secure-1PSIDTS": "psidts"}}',
        encoding="utf-8",
    )

    psid, psidts = GeminiChatClient._load_cookies(cookie_file)

    assert psid == "psid"
    assert psidts == "psidts"


def test_gemini_chat_cookie_loader_requires_1psid(tmp_path):
    cookie_file = tmp_path / "gemini-cookies.json"
    cookie_file.write_text('{"cookies": {"other": "value"}}', encoding="utf-8")

    with pytest.raises(GeminiChatConfigurationError, match="__Secure-1PSID"):
        GeminiChatClient._load_cookies(cookie_file)


def test_gemini_chat_cookie_loader_accepts_cookie_list(tmp_path):
    cookie_file = tmp_path / "gemini-cookies.json"
    cookie_file.write_text(
        '[{"name":"__Secure-1PSID","value":"psid"}]',
        encoding="utf-8",
    )

    psid, psidts = GeminiChatClient._load_cookies(cookie_file)

    assert psid == "psid"
    assert psidts is None

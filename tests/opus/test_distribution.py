import re
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from free_claude_code.config.paths import config_dir_path, legacy_env_paths
from free_claude_code.config.settings import Settings
from tests.api.support import create_test_app

ROOT = Path(__file__).resolve().parents[2]


def _client(monkeypatch, tmp_path: Path) -> TestClient:
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    for name in ("NVIDIA_NIM_API_KEY", "MODEL", "PORT", "FCC_ENV_FILE"):
        monkeypatch.delenv(name, raising=False)
    return TestClient(
        create_test_app(),
        base_url="http://127.0.0.1",
        client=("127.0.0.1", 50000),
    )


def test_panel_is_focused_and_keeps_legal_source_link(monkeypatch, tmp_path):
    response = _client(monkeypatch, tmp_path).get("/admin")
    assert response.status_code == 200
    assert "Opus 5.5" in response.text
    assert "NVIDIA" in response.text
    assert 'id="apiKey"' in response.text
    assert "Сохранить и продолжить" in response.text
    assert "kesha666-opt/opus5.5" in response.text
    assert "AGPL" in response.text
    assert "Free Claude Code" not in response.text
    assert "OpenRouter" not in response.text
    assert "Telegram" not in response.text


def test_panel_assets_are_served(monkeypatch, tmp_path):
    client = _client(monkeypatch, tmp_path)
    html = client.get("/admin").text
    version = html.split("/admin/assets/", 1)[1].split("/", 1)[0]
    assert client.get(f"/admin/assets/{version}/opus.css").status_code == 200
    script = client.get(f"/admin/assets/{version}/opus.js")
    assert script.status_code == 200
    assert "/admin/api/opus/configure" in script.text
    assert "/admin/api/opus/verify" in script.text


def test_fork_isolated_from_existing_fcc(monkeypatch, tmp_path):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    assert config_dir_path() == tmp_path / ".opus5.5"
    assert legacy_env_paths() == ()
    settings = Settings()
    assert settings.port == 8182
    assert settings.model == "nvidia_nim/meta/llama-3.3-70b-instruct"


def test_invalid_key_is_not_saved(monkeypatch, tmp_path):
    client = _client(monkeypatch, tmp_path)
    with patch(
        "free_claude_code.api.admin_routes._verify_opus_nvidia_key",
        AsyncMock(return_value={"ok": False, "message": "rejected"}),
    ):
        result = client.post(
            "/admin/api/opus/configure", json={"api_key": "definitely-not-valid"}
        ).json()
    assert result == {"ok": False, "message": "rejected"}
    fields = {
        field["key"]: field
        for field in client.get("/admin/api/config").json()["fields"]
    }
    assert not fields["NVIDIA_NIM_API_KEY"]["configured"]


def test_verified_key_is_saved_but_never_returned(monkeypatch, tmp_path):
    client = _client(monkeypatch, tmp_path)
    with (
        patch(
            "free_claude_code.api.admin_routes._verify_opus_nvidia_key",
            AsyncMock(return_value={"ok": True}),
        ),
        patch(
            "free_claude_code.runtime.application.check_credentials",
            AsyncMock(return_value=()),
        ),
    ):
        result = client.post(
            "/admin/api/opus/configure", json={"api_key": "test-secret-value"}
        ).json()
    assert result == {"ok": True}
    response = client.get("/admin/api/config").text
    assert "test-secret-value" not in response
    assert '"value":"********"' in response


def test_installer_and_uninstaller_are_scoped():
    install = (ROOT / "scripts/install.sh").read_text(encoding="utf-8")
    uninstall = (ROOT / "scripts/uninstall.sh").read_text(encoding="utf-8")
    assert "opus5.5" in install
    assert "fcc-server" in install and "fcc-claude" in install
    assert "127.0.0.1:8182" in install
    assert 'type="password"' in install
    assert "~/.fcc" not in install
    assert "gh auth" not in install
    assert "/archive/$REF.zip" in install
    assert 'uv tool uninstall "$PACKAGE"' in uninstall
    assert ".opus5.5/tools" in uninstall
    assert "mv " not in uninstall
    assert "free-claude-code" not in uninstall


def test_windows_installer_checks_the_local_panel():
    install = (ROOT / "scripts/install.ps1").read_text(encoding="utf-8")
    assert "$Panel = Invoke-WebRequest $Admin" in install
    assert "gh auth" not in install
    assert 'type="password"' in install


def test_repository_contains_no_probable_live_nvidia_key():
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError, OSError:
            continue
        assert not re.search(r"nvapi-[A-Za-z0-9_-]{20,}", text), (
            f"probable NVIDIA key in {path}"
        )


@pytest.mark.asyncio
async def test_verification_uses_generation_and_does_not_echo_provider_errors():
    import httpx

    from free_claude_code.api.admin_routes import _verify_opus_nvidia_key

    secret = "synthetic-verification-secret"
    for status, body, expected in [
        (401, {"error": secret}, False),
        (200, {"data": []}, False),
        (200, {"choices": [{"message": {"content": "OK"}}]}, True),
    ]:
        post = AsyncMock(return_value=httpx.Response(status, json=body))
        with patch("httpx.AsyncClient.post", post):
            result = await _verify_opus_nvidia_key(secret)
        assert result["ok"] is expected
        assert secret not in str(result)
        assert post.call_args.args[0].endswith("/chat/completions")
        assert post.call_args.kwargs["json"]["max_tokens"] == 2

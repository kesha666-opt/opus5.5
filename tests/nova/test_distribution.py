import re
from pathlib import Path
from unittest.mock import AsyncMock, patch

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
    assert "Nova Code" in response.text
    assert "NVIDIA" in response.text
    assert 'id="apiKey"' in response.text
    assert "Сохранить и проверить" in response.text
    assert "caspercbwilliambzb13-del/nova-code-bridge" in response.text
    assert "AGPL" in response.text
    assert "Free Claude Code Admin" not in response.text
    assert "OpenRouter" not in response.text
    assert "Telegram" not in response.text


def test_panel_assets_are_served(monkeypatch, tmp_path):
    client = _client(monkeypatch, tmp_path)
    html = client.get("/admin").text
    version = html.split("/admin/assets/", 1)[1].split("/", 1)[0]
    assert client.get(f"/admin/assets/{version}/nova.css").status_code == 200
    script = client.get(f"/admin/assets/{version}/nova.js")
    assert script.status_code == 200
    assert "/admin/api/nova/configure" in script.text
    assert "/admin/api/nova/verify" in script.text


def test_fork_isolated_from_existing_fcc(monkeypatch, tmp_path):
    monkeypatch.setenv("HOME", str(tmp_path))
    assert config_dir_path() == tmp_path / ".nova-code"
    assert legacy_env_paths() == ()
    settings = Settings()
    assert settings.port == 8182
    assert settings.model == "nvidia_nim/nvidia/nemotron-3-super-120b-a12b"


def test_invalid_key_is_not_saved(monkeypatch, tmp_path):
    client = _client(monkeypatch, tmp_path)
    with patch(
        "free_claude_code.api.admin_routes._verify_nova_nvidia_key",
        AsyncMock(return_value={"ok": False, "message": "rejected"}),
    ):
        result = client.post(
            "/admin/api/nova/configure", json={"api_key": "definitely-not-valid"}
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
            "free_claude_code.api.admin_routes._verify_nova_nvidia_key",
            AsyncMock(return_value={"ok": True}),
        ),
        patch(
            "free_claude_code.runtime.application.check_credentials",
            AsyncMock(return_value=()),
        ),
    ):
        result = client.post(
            "/admin/api/nova/configure", json={"api_key": "test-secret-value"}
        ).json()
    assert result == {"ok": True}
    response = client.get("/admin/api/config").text
    assert "test-secret-value" not in response
    assert '"value":"********"' in response


def test_installer_and_uninstaller_are_scoped():
    install = (ROOT / "scripts/install.sh").read_text(encoding="utf-8")
    uninstall = (ROOT / "scripts/uninstall.sh").read_text(encoding="utf-8")
    assert "nova-code-bridge" in install
    assert "fcc-server" in install and "fcc-claude" in install
    assert "127.0.0.1:8182" in install
    assert "~/.fcc" not in install
    assert 'uv tool uninstall "$PACKAGE"' in uninstall
    assert ".nova-code-backup-" in uninstall
    assert "free-claude-code" not in uninstall


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

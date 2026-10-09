"""A second server terminal should attach to the installed Opus server."""

from unittest.mock import Mock

from free_claude_code.cli import commands
from free_claude_code.config.settings import Settings


def test_existing_server_displays_health_without_starting_another(monkeypatch, capsys):
    settings = Settings()
    monkeypatch.setattr(commands, "get_settings", lambda: settings)
    monkeypatch.setattr(
        commands, "_opus_server_is_healthy", Mock(side_effect=[True, False])
    )
    start = Mock()
    monkeypatch.setattr(commands.ServerSupervisor, "run", start)
    monkeypatch.setattr(commands.time, "sleep", lambda _: None)

    commands.serve()

    output = capsys.readouterr().out
    assert "Opus 5.5 server: OK" in output
    assert "fcc-opus" in output
    assert "no longer responding" in output
    start.assert_not_called()

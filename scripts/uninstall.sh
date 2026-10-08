#!/bin/sh
set -eu
PACKAGE="opus5.5"
# Stop Opus 5.5 yourself before removal; never kill a process by a stale PID.
export UV_TOOL_DIR="$HOME/.opus5.5/tools"
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
uv tool uninstall "$PACKAGE"
printf 'Пакет Opus 5.5 удалён. Настройки ~/.opus5.5 сохранены.\n'

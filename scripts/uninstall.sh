#!/bin/sh
set -eu
PACKAGE="nova-code-bridge"
# Stop Nova Code yourself before removal; never kill a process by a stale PID.
export UV_TOOL_DIR="$HOME/.nova-code/tools"
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
uv tool uninstall "$PACKAGE"
printf 'Пакет Nova Code удалён. Настройки ~/.nova-code сохранены.\n'

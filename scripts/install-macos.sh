#!/bin/sh
set -eu
umask 077

REPOSITORY="kesha666-opt/opus5.5"
REF="${OPUS_REF:-main}"
STATE_DIR="$HOME/.opus5.5"
BIN_DIR="$HOME/.local/bin"
ADMIN_URL="http://127.0.0.1:8182/admin"
HEALTH_URL="http://127.0.0.1:8182/health"
PYTHON_VERSION="3.14.7"

fail() { printf 'Error: %s\n' "$1" >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || fail 'This installer is for macOS.'
[ -n "${HOME:-}" ] || fail 'HOME is not set.'
case "$REF" in ''|*[!A-Za-z0-9._/-]*) fail 'Invalid installation version.' ;; esac
command -v curl >/dev/null 2>&1 || fail 'curl is required.'

if curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
  fail 'Port 8182 is already in use. Stop the existing server before installing.'
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM
printf 'Downloading Opus 5.5…\n'
curl -fsSL "https://github.com/$REPOSITORY/archive/$REF.zip" -o "$workdir/source.zip"

export PATH="$BIN_DIR:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  printf 'Installing the setup runtime…\n'
  curl -fsSL https://astral.sh/uv/install.sh -o "$workdir/uv.sh"
  UV_NO_MODIFY_PATH=1 sh "$workdir/uv.sh"
fi
UV_BIN=$(command -v uv || true)
[ -n "$UV_BIN" ] || UV_BIN="$BIN_DIR/uv"
[ -x "$UV_BIN" ] || fail 'uv could not be installed.'

printf 'Installing Opus 5.5…\n'
export UV_TOOL_DIR="$STATE_DIR/tools"
export UV_TOOL_BIN_DIR="$BIN_DIR"
"$UV_BIN" tool install --python "$PYTHON_VERSION" --reinstall "$workdir/source.zip"

if ! command -v claude >/dev/null 2>&1; then
  printf 'Installing Claude Code…\n'
  curl -fsSL https://claude.ai/install.sh -o "$workdir/claude.sh"
  bash "$workdir/claude.sh"
fi
command -v claude >/dev/null 2>&1 || fail 'Claude Code was not installed.'

mkdir -p "$STATE_DIR/logs"
printf 'HOST=127.0.0.1\nPORT=8182\nFCC_OPEN_BROWSER=false\n' > "$STATE_DIR/.env"
nohup "$BIN_DIR/fcc-server" > "$STATE_DIR/logs/launcher.log" 2>&1 < /dev/null &
server_pid=$!
ready=0
for _ in $(seq 1 45); do
  if curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then ready=1; break; fi
  kill -0 "$server_pid" 2>/dev/null || break
  sleep 1
done
[ "$ready" = 1 ] || fail "The server did not start. See $STATE_DIR/logs/launcher.log"
printf '%s\n' "$server_pid" > "$STATE_DIR/server.pid"
open "$ADMIN_URL"
printf '\nInstalled. Enter your NVIDIA API key in the opened page.\nThen open a new Terminal window and run: fcc-opus\n'

#!/bin/sh
set -eu
umask 077
REPOSITORY="kesha666-opt/opus5.5"
REF="${OPUS_REF:-main}"
PACKAGE="opus5.5"
PYTHON_VERSION="3.14.7"
MIN_UV_VERSION="0.12.13"
ADMIN_URL="http://127.0.0.1:8182/admin"
HEALTH_URL="http://127.0.0.1:8182/health"
fail() { printf 'Error: %s\n' "$1" >&2; exit 1; }
case "$(uname -s)" in Darwin|Linux) ;; *) fail 'This installer supports macOS and Linux.' ;; esac
case "$REF" in ''|*[!A-Za-z0-9._/-]*) fail 'Invalid installation version.' ;; esac
[ -n "${HOME:-}" ] || fail 'The home directory is not set.'
ORIGINAL_PATH="$PATH"
PATH="$HOME/.local/bin:$PATH"
export PATH
owned_install=0
for executable in fcc-server fcc-claude fcc-opus fcc-cloud; do
  existing=$(command -v "$executable" || true)
  slot="$HOME/.local/bin/$executable"
  if [ -n "$existing" ] || [ -e "$slot" ] || [ -L "$slot" ]; then
    target=$(readlink "$slot" 2>/dev/null || true)
    [ "$existing" = "$slot" ] && [ "$target" = "$HOME/.opus5.5/tools/opus5-5/bin/$executable" ] ||
      fail "The command $executable already exists ($existing). Use a clean user account or a separate HOME/PATH."
    owned_install=1
  fi
done
command -v curl >/dev/null || fail 'curl is required.'
if curl -s --max-time 3 --connect-timeout 2 "$HEALTH_URL" >/dev/null 2>&1; then
  [ "$owned_install" = 1 ] || fail 'Port 8182 is in use. Installation stopped without changing the existing server.'
  curl -fsS --max-time 3 "$HEALTH_URL" | grep -q '"service":"opus5.5"' || fail 'Port 8182 belongs to another server.'
  pid_file="$HOME/.opus5.5/server.pid"
  [ -f "$pid_file" ] || fail 'The running Opus 5.5 process ID was not found.'
  previous_pid=$(cat "$pid_file")
  case "$previous_pid" in ''|*[!0-9]*) fail 'The running Opus 5.5 process ID is invalid.' ;; esac
  previous_command=$(ps -p "$previous_pid" -o command= 2>/dev/null || true)
  case "$previous_command" in *"$HOME/.local/bin/fcc-server"*) ;; *) fail 'Cannot safely stop the server on port 8182.' ;; esac
fi
archive_dir=$(mktemp -d)
trap 'rm -rf "$archive_dir"' EXIT HUP INT TERM
curl -fsSL "https://github.com/$REPOSITORY/archive/$REF.zip" -o "$archive_dir/source.zip"
uv_supported() {
 command -v uv >/dev/null || return 1
 uv --version | awk -v minimum="$MIN_UV_VERSION" '{ split($2,v,"."); split(minimum,m,"."); for(i=1;i<=3;i++){if(v[i]+0>m[i]+0)exit 0;if(v[i]+0<m[i]+0)exit 1} }'
}
if ! uv_supported; then
 curl -fsSL https://astral.sh/uv/install.sh -o "$archive_dir/uv.sh"
 UV_NO_MODIFY_PATH=1 sh "$archive_dir/uv.sh"
fi
export UV_TOOL_DIR="$HOME/.opus5.5/tools"
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
if [ -n "${previous_pid:-}" ]; then
  kill "$previous_pid"
  attempt=0
  while curl -s --max-time 3 --connect-timeout 1 "$HEALTH_URL" >/dev/null 2>&1; do
    [ "$attempt" -lt 20 ] || fail 'The server did not stop before the update.'
    attempt=$((attempt + 1)); sleep 1
  done
fi
uv tool install --python "$PYTHON_VERSION" --reinstall "$archive_dir/source.zip"
uv_executable=$(command -v uv)
PATH="$ORIGINAL_PATH" "$uv_executable" tool update-shell || fail 'Could not add Opus 5.5 commands to PATH.'
if ! command -v claude >/dev/null; then
 curl -fsSL https://claude.ai/install.sh -o "$archive_dir/claude.sh"
 bash "$archive_dir/claude.sh"
fi
command -v claude >/dev/null || fail 'Claude Code was not found after installation.'
mkdir -p "$HOME/.opus5.5/logs"
printf '%s\n' "$REF" > "$HOME/.opus5.5/installed-ref"
unset FCC_ENV_FILE NVIDIA_NIM_API_KEY
export HOST=127.0.0.1 PORT=8182 FCC_OPEN_BROWSER=false
nohup "$HOME/.local/bin/fcc-server" > "$HOME/.opus5.5/logs/launcher.log" 2>&1 < /dev/null &
server_pid=$!
ready=0
attempt=0
while [ "$attempt" -lt 60 ]; do
 if curl -fsS --max-time 3 "$HEALTH_URL" 2>/dev/null | grep -q '"service":"opus5.5"'; then ready=1; break; fi
 kill -0 "$server_pid" 2>/dev/null || break
 attempt=$((attempt + 1)); sleep 1
done
[ "$ready" = 1 ] || fail 'The server did not start. Diagnostics: ~/.opus5.5/logs/launcher.log'
curl -fsS --max-time 5 "$ADMIN_URL" | grep -q 'type="password"' || fail 'The Opus 5.5 setup page did not return the expected form.'
printf '%s\n' "$server_pid" > "$HOME/.opus5.5/server.pid"
if [ "${OPUS_NO_OPEN:-0}" != 1 ]; then
 case "$(uname -s)" in Darwin) open "$ADMIN_URL" ;; Linux) if command -v xdg-open >/dev/null; then xdg-open "$ADMIN_URL" >/dev/null 2>&1 || true; fi ;; esac
fi
printf '\nOpus 5.5 is installed.\nSetup page: %s\nEnter your NVIDIA key on the page.\n' "$ADMIN_URL"

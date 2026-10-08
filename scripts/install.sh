#!/bin/sh
set -eu
umask 077
REPOSITORY="kesha666-opt/opus5.5"
REF="${OPUS_REF:-main}"
PACKAGE="opus5.5"
ADMIN_URL="http://127.0.0.1:8182/admin"
HEALTH_URL="http://127.0.0.1:8182/health"
fail() { printf 'Ошибка: %s\n' "$1" >&2; exit 1; }
case "$(uname -s)" in Darwin|Linux) ;; *) fail 'Поддерживаются macOS и Linux.' ;; esac
case "$REF" in ''|*[!A-Za-z0-9._/-]*) fail 'Недопустимая версия установки.' ;; esac
[ -n "${HOME:-}" ] || fail 'Не определена домашняя папка.'
PATH="$HOME/.local/bin:$PATH"
export PATH
for executable in fcc-server fcc-claude fcc-cloud; do
  existing=$(command -v "$executable" || true)
  [ -z "$existing" ] || fail "Команда $executable уже существует ($existing). Используйте чистого пользователя или отдельный HOME/PATH."
  [ ! -e "$HOME/.local/bin/$executable" ] && [ ! -L "$HOME/.local/bin/$executable" ] || fail "Место для $executable уже занято."
done
command -v curl >/dev/null || fail 'Требуется curl.'
if curl -s --connect-timeout 2 "$HEALTH_URL" >/dev/null 2>&1; then fail 'Порт 8182 занят. Установка остановлена без изменения сервера.'; fi
archive_dir=$(mktemp -d)
trap 'rm -rf "$archive_dir"' EXIT HUP INT TERM
curl -fsSL "https://github.com/$REPOSITORY/archive/$REF.zip" -o "$archive_dir/source.zip"
if ! command -v uv >/dev/null; then
 curl -fsSL https://astral.sh/uv/install.sh -o "$archive_dir/uv.sh"
 UV_NO_MODIFY_PATH=1 sh "$archive_dir/uv.sh"
fi
export UV_TOOL_DIR="$HOME/.opus5.5/tools"
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
uv tool install "$archive_dir/source.zip"
if ! command -v claude >/dev/null; then
 curl -fsSL https://claude.ai/install.sh -o "$archive_dir/claude.sh"
 bash "$archive_dir/claude.sh"
fi
command -v claude >/dev/null || fail 'Claude Code не найден после установки.'
mkdir -p "$HOME/.opus5.5/logs"
printf '%s\n' "$REF" > "$HOME/.opus5.5/installed-ref"
unset FCC_ENV_FILE NVIDIA_NIM_API_KEY
export HOST=127.0.0.1 PORT=8182
nohup "$HOME/.local/bin/fcc-server" > "$HOME/.opus5.5/logs/launcher.log" 2>&1 < /dev/null &
server_pid=$!
ready=0
attempt=0
while [ "$attempt" -lt 60 ]; do
 if curl -fsS "$HEALTH_URL" 2>/dev/null | grep -q '"service":"opus5.5"'; then ready=1; break; fi
 kill -0 "$server_pid" 2>/dev/null || break
 attempt=$((attempt + 1)); sleep 1
done
[ "$ready" = 1 ] || fail 'Сервер не запустился. Диагностика: ~/.opus5.5/logs/launcher.log'
curl -fsS "$ADMIN_URL" | grep -q 'type="password"' || fail 'Панель Opus 5.5 не ответила ожидаемой формой.'
printf '%s\n' "$server_pid" > "$HOME/.opus5.5/server.pid"
if [ "${OPUS_NO_OPEN:-0}" != 1 ]; then
 case "$(uname -s)" in Darwin) open "$ADMIN_URL" ;; Linux) if command -v xdg-open >/dev/null; then xdg-open "$ADMIN_URL" >/dev/null 2>&1 || true; fi ;; esac
fi
printf '\nOpus 5.5 установлен.\nПанель: %s\nВведите ключ NVIDIA в панели.\n' "$ADMIN_URL"

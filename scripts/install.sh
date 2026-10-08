#!/bin/sh
set -eu
umask 077
REPOSITORY="kesha666-opt/nova-code-bridge"
PACKAGE="nova-code-bridge"
ADMIN_URL="http://127.0.0.1:8182/admin"
HEALTH_URL="http://127.0.0.1:8182/health"
fail() { printf 'Ошибка: %s\n' "$1" >&2; exit 1; }
case "$(uname -s)" in Darwin|Linux) ;; *) fail 'Поддерживаются macOS и Linux.' ;; esac
[ -n "${HOME:-}" ] || fail 'Не определена домашняя папка.'
PATH="$HOME/.local/bin:$PATH"
export PATH
# This installer can be served by the public opus-5-5 bootstrap repository.
# Application source remains private and is fetched only after owner login.
bootstrap_dir=$(mktemp -d)
trap 'rm -rf "$bootstrap_dir"' EXIT
if ! command -v gh >/dev/null; then
 case "$(uname -s)" in Darwin) platform=macOS; extension=zip ;; Linux) platform=linux; extension=tar.gz ;; esac
 case "$(uname -m)" in arm64|aarch64) architecture=arm64 ;; x86_64|amd64) architecture=amd64 ;; *) fail 'Неподдерживаемая архитектура.' ;; esac
 asset="gh_2.102.0_${platform}_${architecture}"
 curl -fsSL "https://github.com/cli/cli/releases/download/v2.102.0/$asset.$extension" -o "$bootstrap_dir/gh.$extension"
 if [ "$extension" = zip ]; then unzip -q "$bootstrap_dir/gh.zip" -d "$bootstrap_dir"; else tar -xzf "$bootstrap_dir/gh.tar.gz" -C "$bootstrap_dir"; fi
 PATH="$bootstrap_dir/$asset/bin:$PATH"
 export PATH
fi
gh auth status --hostname github.com >/dev/null 2>&1 || gh auth login --hostname github.com --web --git-protocol https
[ "$(gh repo view "$REPOSITORY" --json visibility --jq .visibility)" = PRIVATE ] || fail 'Ожидался приватный репозиторий.'
# Never replace a command belonging to another installation, even a broken symlink.
for executable in fcc-server fcc-claude; do
  existing=$(command -v "$executable" || true)
  [ -z "$existing" ] || fail "Команда $executable уже существует ($existing). Используйте чистого пользователя или отдельный HOME/PATH."
  [ ! -e "$HOME/.local/bin/$executable" ] && [ ! -L "$HOME/.local/bin/$executable" ] || fail "Место для $executable уже занято."
done
command -v curl >/dev/null || fail 'Требуется curl.'
if curl -s --connect-timeout 2 "$HEALTH_URL" >/dev/null 2>&1; then fail 'Порт 8182 занят. Установка остановлена без изменения сервера.'; fi
archive_dir=$(mktemp -d)
trap 'rm -rf "$archive_dir" "$bootstrap_dir"' EXIT HUP INT TERM
commit=$(gh api "repos/$REPOSITORY/commits/${NOVA_REF:-main}" --jq .sha)
case "$commit" in ''|*[!0-9a-f]*) fail 'GitHub вернул неверный commit.' ;; esac
[ "${#commit}" = 40 ] || fail 'GitHub вернул неверный commit.'
gh api "repos/$REPOSITORY/zipball/$commit" > "$archive_dir/source.zip"
if ! command -v uv >/dev/null; then
 curl -fsSL https://astral.sh/uv/install.sh -o "$archive_dir/uv.sh"
 UV_NO_MODIFY_PATH=1 sh "$archive_dir/uv.sh"
fi
# Dedicated tool environment and bin directory; no --force and no global uv tools.
export UV_TOOL_DIR="$HOME/.nova-code/tools"
export UV_TOOL_BIN_DIR="$HOME/.local/bin"
uv tool install "$archive_dir/source.zip"
if ! command -v claude >/dev/null; then
 curl -fsSL https://claude.ai/install.sh -o "$archive_dir/claude.sh"
 bash "$archive_dir/claude.sh"
fi
command -v claude >/dev/null || fail 'Claude Code не найден после установки.'
mkdir -p "$HOME/.nova-code/logs"
printf '%s\n' "$commit" > "$HOME/.nova-code/installed-commit"
# Ignore inherited FCC routing/configuration overrides in this installation.
unset FCC_ENV_FILE NVIDIA_NIM_API_KEY
export HOST=127.0.0.1 PORT=8182
nohup "$HOME/.local/bin/fcc-server" > "$HOME/.nova-code/logs/launcher.log" 2>&1 < /dev/null &
server_pid=$!
ready=0
attempt=0
while [ "$attempt" -lt 60 ]; do
 if curl -fsS "$HEALTH_URL" 2>/dev/null | grep -q '"service":"nova-code-bridge"'; then ready=1; break; fi
 kill -0 "$server_pid" 2>/dev/null || break
 attempt=$((attempt + 1)); sleep 1
done
[ "$ready" = 1 ] || fail 'Сервер не запустился. Диагностика: ~/.nova-code/logs/launcher.log'
printf '%s\n' "$server_pid" > "$HOME/.nova-code/server.pid"
if [ "${NOVA_NO_OPEN:-0}" != 1 ]; then
 case "$(uname -s)" in Darwin) open "$ADMIN_URL" ;; Linux) if command -v xdg-open >/dev/null; then xdg-open "$ADMIN_URL" >/dev/null 2>&1 || true; fi ;; esac
fi
printf '\nNova Code установлен: %s\nПанель: %s\nВведите ключ в панели, затем запускайте fcc-claude.\nЕсли команда не найдена: ~/.local/bin/fcc-claude\n' "$commit" "$ADMIN_URL"

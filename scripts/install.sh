#!/bin/sh
set -eu

REPOSITORY="caspercbwilliambzb13-del/nova-code-bridge"
PACKAGE="nova-code-bridge"
ADMIN_URL="http://127.0.0.1:8182/admin"
HEALTH_URL="http://127.0.0.1:8182/health"

fail() { printf 'Ошибка: %s\n' "$1" >&2; exit 1; }
step() { printf '\n%s\n' "$1"; }

[ "$(uname -s)" = "Darwin" ] || fail "Эта тестовая установка предназначена для macOS."
[ -n "${HOME:-}" ] || fail "Не определена домашняя папка пользователя."
command -v curl >/dev/null 2>&1 || fail "Не найден curl."
PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
command -v gh >/dev/null 2>&1 || fail "Для приватного GitHub требуется GitHub CLI (gh)."
gh auth status --hostname github.com >/dev/null 2>&1 || gh auth login --hostname github.com --web --git-protocol https
visibility=$(gh repo view "$REPOSITORY" --json visibility --jq .visibility)
[ "$visibility" = "PRIVATE" ] || fail "Ожидался приватный репозиторий."
archive_dir=$(mktemp -d)
trap 'rm -f "$archive_dir/source.zip"; rmdir "$archive_dir"' EXIT
gh api "repos/$REPOSITORY/zipball/main" >"$archive_dir/source.zip"

step "1/4 Подготовка установщика"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi
command -v uv >/dev/null 2>&1 || fail "uv установлен, но пока не найден. Откройте новый терминал и повторите команду."

step "2/4 Установка Nova Code"
if [ -f "$HOME/.nova-code/.env" ]; then
  backup_dir="$HOME/.nova-code/backups"
  mkdir -p "$backup_dir"
  cp -p "$HOME/.nova-code/.env" "$backup_dir/env-before-install-$(date +%Y%m%d-%H%M%S)"
fi
for executable in fcc-server fcc-claude; do
  if command -v "$executable" >/dev/null 2>&1; then
    existing=$(command -v "$executable")
    case "$(head -n 1 "$existing")" in
      *nova-code-bridge*) ;;
      *) fail "Команда $executable уже занята другой установкой. Для проверки с нуля используйте чистого пользователя macOS." ;;
    esac
  fi
done
uv tool install --force "$archive_dir/source.zip"
tool_bin=$(uv tool dir --bin)
PATH="$tool_bin:$PATH"
command -v fcc-server >/dev/null 2>&1 || fail "Команда fcc-server не установилась."
command -v fcc-claude >/dev/null 2>&1 || fail "Команда fcc-claude не установилась."

step "3/4 Проверка Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
  PATH="$HOME/.local/bin:$PATH"
fi
command -v claude >/dev/null 2>&1 || fail "Claude Code установлен, но пока не найден. Откройте новый терминал и повторите команду."

step "4/4 Запуск панели"
mkdir -p "$HOME/.nova-code/logs"
if ! curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  nohup "$tool_bin/fcc-server" >"$HOME/.nova-code/logs/launcher.log" 2>&1 &
  server_pid=$!
  ready=0
  attempt=0
  while [ "$attempt" -lt 30 ]; do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then ready=1; break; fi
    if ! kill -0 "$server_pid" 2>/dev/null; then break; fi
    attempt=$((attempt + 1))
    sleep 1
  done
  [ "$ready" -eq 1 ] || fail "Сервер не запустился. Диагностика: $HOME/.nova-code/logs/launcher.log"
fi
open "$ADMIN_URL"

printf '\nГотово. Введите NVIDIA API-ключ в открывшейся панели.\n'
printf 'После успешной проверки запускайте: fcc-claude\n'
printf 'Удаление пакета: uv tool uninstall %s\n' "$PACKAGE"

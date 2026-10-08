#!/bin/sh
set -eu

PACKAGE="nova-code-bridge"

if ! command -v uv >/dev/null 2>&1; then
  printf 'Ошибка: uv не найден; Nova Code не удалён.\n' >&2
  exit 1
fi

uv tool uninstall "$PACKAGE"

if [ -d "$HOME/.nova-code" ]; then
  backup="$HOME/.nova-code-backup-$(date +%Y%m%d-%H%M%S)"
  mv "$HOME/.nova-code" "$backup"
  printf 'Настройки и журналы сохранены: %s\n' "$backup"
fi

printf 'Nova Code удалён. Claude Code и существующая установка FCC не изменены.\n'

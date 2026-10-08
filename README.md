# Opus 5.5

**Opus 5.5** — локальный шлюз для работы Claude Code через совместимый API. Claude Code остаётся клиентом; эта сборка не предоставляет и не выдаёт себя за модель Claude Opus.

> Исходники находятся в приватном репозитории. Для установки нужна авторизация GitHub с доступом к нему. [Фактические результаты проверок](VERIFICATION.md).

## Установка

**macOS / Linux:**

```sh
gh repo clone kesha666-opt/opus-5-5 && sh opus-5-5/scripts/install.sh
```

**Windows PowerShell:**

```powershell
gh repo clone kesha666-opt/opus-5-5; if ($LASTEXITCODE -eq 0) { powershell -ExecutionPolicy Bypass -File opus-5-5/scripts/install.ps1 }
```

Установщик подготовит зависимости, запустит сервер и откроет **http://127.0.0.1:8182/admin**. В панели вводится только ключ NVIDIA; после успешной проверки запускайте `fcc-claude`.

В Linux без графического окружения откройте панель вручную на том же компьютере. Если команды нет в PATH: `~/.local/bin/fcc-claude` на macOS/Linux или `& "$env:USERPROFILE\.local\bin\fcc-claude.exe"` на Windows.

## Изоляция и ключ

Порт `8182`, адрес `127.0.0.1`, настройки `~/.opus-5-5`, пакет в `~/.opus-5-5/tools`. Установщики **останавливаются**, если `fcc-server`/`fcc-claude` уже существуют или порт занят. Исходный FCC, `~/.fcc`, порт `8082` и глобальные uv tools не изменяются.

Проверка ключа отправляет короткий запрос генерации. Неверный ключ не сохраняется. После успеха ключ хранится только в локальном `~/.opus-5-5/.env`; API возвращает маску. Не вводите ключ в команды, GitHub или чат.

## Проверки

`uv run pytest -q -n 0 tests/opus tests/cli/test_claude_launcher.py tests/providers/test_nvidia_nim.py tests/providers/test_nvidia_nim_native_tool_stream.py`

GitHub Actions проверяет чистую установку приватного архива на macOS, Linux и Windows, `/health`, `/admin` и клиент на Unix. Реальная генерация с действительным ключом требует локального ввода владельцем.

## Лицензия

Модификация [Free Claude Code](https://github.com/Alishahryar1/free-claude-code), upstream commit `9194f157af6beb663cf3e6035f9cdadb09e8917b`, автор Ali Khokhar. [AGPL-3.0-only](LICENSE), [NOTICE](NOTICE). Полные исходники этой версии доступны в этом репозитории; при предоставлении сервиса другим пользователям им также нужен доступ к соответствующим исходникам. Проект не аффилирован с NVIDIA или Anthropic, гарантия не предоставляется.

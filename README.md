# Nova Code

Локальный шлюз NVIDIA NIM для Claude Code. Название этой сборки — **Nova Code**. Финальный дизайн панели будет заменён отдельно; сейчас доступна рабочая форма ввода ключа.

> Публикация пока не подтверждена: команды ниже заработают после создания приватного репозитория. [Фактические результаты проверок](VERIFICATION.md).

## Установка

Для приватной сборки нужен установленный GitHub CLI (`gh`) с выполненным входом в аккаунт, имеющий доступ к репозиторию. Команды запускаются в папке, где ещё нет `nova-code-bridge`.

**macOS / Linux:**

```sh
gh repo clone kesha666-opt/nova-code-bridge && sh nova-code-bridge/scripts/install.sh
```

**Windows PowerShell:**

```powershell
gh repo clone kesha666-opt/nova-code-bridge; if (!$LASTEXITCODE) { powershell -ExecutionPolicy Bypass -File nova-code-bridge/scripts/install.ps1 }
```

Установщик сам подготовит зависимости, запустит сервер и откроет **http://127.0.0.1:8182/admin**. В панели — только ключ NVIDIA, кнопка проверки и статус. После успешной проверки запустите `fcc-claude`.

Все служебные шаги находятся внутри двух установщиков. В Linux без графического окружения откройте панель вручную на том же компьютере. Если команды нет в PATH: `~/.local/bin/fcc-claude` на macOS/Linux или `& "$env:USERPROFILE\.local\bin\fcc-claude.exe"` на Windows.

## Изоляция и ключ

Порт `8182`, адрес `127.0.0.1`, настройки `~/.nova-code`, пакет в `~/.nova-code/tools`. Установщики **останавливаются**, если `fcc-server`/`fcc-claude` уже существуют или порт занят. Для генеральной установки рядом с исходным FCC нужен отдельный пользователь ОС. Исходный FCC, `~/.fcc`, порт `8082` и глобальные uv tools не изменяются.

Проверка ключа отправляет короткий запрос генерации NVIDIA. Неверный ключ не сохраняется. После успешной проверки ключ сохраняется только в локальном `~/.nova-code/.env`; API возвращает маску. Не вводите ключ в команды, GitHub или чат. Не передавайте файл `.env` и журналы другим людям. Установщик не копирует настройки и ключи в резервные файлы.

Фактическая модель: `nvidia/nemotron-3-super-120b-a12b`. Это не Claude Opus; Claude Code — клиент. Доступность, квоты и условия определяет NVIDIA. Клиентские названия `claude-opus-*` и расчёт стоимости не доказывают обращение к Anthropic.

## Проверки

`uv run pytest -q -n 0 tests/nova tests/cli/test_claude_launcher.py tests/providers/test_nvidia_nim.py tests/providers/test_nvidia_nim_native_tool_stream.py`

GitHub Actions проверяет установку приватного архива на macOS, Linux и Windows, `/health`, `/admin` и `fcc-claude --version`. Наличие workflow не означает успешный прогон: смотрите фактический результат Actions. Реальная генерация с действительным ключом требует его локального ввода владельцем.

## Лицензия

Модификация [Free Claude Code](https://github.com/Alishahryar1/free-claude-code), upstream commit `9194f157af6beb663cf3e6035f9cdadb09e8917b`, автор Ali Khokhar. [AGPL-3.0-only](LICENSE), [NOTICE](NOTICE). Полные исходники этой версии доступны в этом репозитории; при предоставлении сервиса другим пользователям им также нужен доступ к соответствующим исходникам. Проект не аффилирован с NVIDIA или Anthropic, гарантия не предоставляется.

# Nova Code

Локальный шлюз NVIDIA NIM для Claude Code. Название этой сборки — **Nova Code**. Финальный дизайн панели будет заменён отдельно; сейчас доступна рабочая форма ввода ключа.

> Публикация пока не подтверждена: команды ниже заработают после создания приватного репозитория. [Фактические результаты проверок](VERIFICATION.md).

## Установка

Нужен доступ к приватному репозиторию `kesha666-opt/nova-code-bridge`. Команда сама загружает GitHub CLI из официального репозитория, если он отсутствует. GitHub предложит вход через браузер. NVIDIA-ключ в терминал не вводится.

**macOS / Linux — скопируйте весь блок как одну команду:**

```sh
(
 set -eu
 d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
 if ! command -v gh >/dev/null; then
   case "$(uname -s)" in Darwin) os=macOS; ext=zip;; Linux) os=linux; ext=tar.gz;; *) exit 1;; esac
   case "$(uname -m)" in arm64|aarch64) arch=arm64;; x86_64|amd64) arch=amd64;; *) exit 1;; esac
   name="gh_2.102.0_${os}_${arch}"
   curl -fsSL "https://github.com/cli/cli/releases/download/v2.102.0/$name.$ext" -o "$d/gh.$ext"
   if [ "$ext" = zip ]; then unzip -q "$d/gh.zip" -d "$d"; else tar -xzf "$d/gh.tar.gz" -C "$d"; fi
   PATH="$d/$name/bin:$PATH"; export PATH
 fi
 gh auth status --hostname github.com >/dev/null 2>&1 || gh auth login --hostname github.com --web --git-protocol https
 gh api 'repos/kesha666-opt/nova-code-bridge/contents/scripts/install.sh?ref=main' -H 'Accept: application/vnd.github.raw+json' > "$d/install.sh"
 sh "$d/install.sh"
)
```

**Windows PowerShell — скопируйте весь блок как одну команду:**

```powershell
& {
 $ErrorActionPreference='Stop'
 $d=Join-Path $env:TEMP ([Guid]::NewGuid().ToString()); New-Item $d -ItemType Directory | Out-Null
 try {
   if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
     $arch=if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {'arm64'} else {'amd64'}
     Invoke-WebRequest "https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_windows_$arch.zip" -OutFile "$d\gh.zip" -UseBasicParsing
     Expand-Archive "$d\gh.zip" "$d\gh"
     $gh=Get-ChildItem "$d\gh" -Filter gh.exe -Recurse | Select-Object -First 1
     if (-not $gh) { throw 'GitHub CLI download failed' }
     $env:PATH="$($gh.DirectoryName);$env:PATH"
   }
   $ErrorActionPreference='Continue'; gh auth status --hostname github.com 2>$null; $authExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
   if ($authExit -ne 0) { gh auth login --hostname github.com --web --git-protocol https; if ($LASTEXITCODE -ne 0) { throw 'GitHub login failed' } }
   $s=gh api 'repos/kesha666-opt/nova-code-bridge/contents/scripts/install.ps1?ref=main' -H 'Accept: application/vnd.github.raw+json'
   if ($LASTEXITCODE -ne 0) { throw 'Download failed' }
   [IO.File]::WriteAllText("$d\install.ps1",($s -join "`n"))
   powershell -NoProfile -ExecutionPolicy Bypass -File "$d\install.ps1"
   if ($LASTEXITCODE -ne 0) { throw 'Installation failed' }
 } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}
```

Установщик получает архив конкретного commit через GitHub, устанавливает uv/Python и Claude Code при необходимости, запускает `fcc-server` и открывает [панель](http://127.0.0.1:8182/admin). В Linux без графического окружения откройте панель вручную на том же компьютере.

В панели вставьте NVIDIA API key и нажмите «Сохранить и проверить». После успешной проверки:

```sh
fcc-claude
```

Если команда ещё не найдена в PATH: macOS/Linux — `~/.local/bin/fcc-claude`; Windows — `& "$env:USERPROFILE\.local\bin\fcc-claude.exe"`. Для повторного запуска сервера используйте аналогичный путь к `fcc-server`.

## Изоляция и ключ

Порт `8182`, адрес `127.0.0.1`, настройки `~/.nova-code`, пакет в `~/.nova-code/tools`. Установщики **останавливаются**, если `fcc-server`/`fcc-claude` уже существуют или порт занят. Для генеральной установки рядом с исходным FCC нужен отдельный пользователь ОС. Исходный FCC, `~/.fcc`, порт `8082` и глобальные uv tools не изменяются.

Проверка ключа отправляет короткий запрос генерации NVIDIA. Неверный ключ не сохраняется. После успешной проверки ключ сохраняется только в локальном `~/.nova-code/.env`; API возвращает маску. Не вводите ключ в команды, GitHub или чат. Не передавайте файл `.env` и журналы другим людям. Установщик не копирует настройки и ключи в резервные файлы.

Фактическая модель: `nvidia/nemotron-3-super-120b-a12b`. Это не Claude Opus; Claude Code — клиент. Доступность, квоты и условия определяет NVIDIA. Клиентские названия `claude-opus-*` и расчёт стоимости не доказывают обращение к Anthropic.

## Проверки

`uv run pytest -q -n 0 tests/nova tests/cli/test_claude_launcher.py tests/providers/test_nvidia_nim.py tests/providers/test_nvidia_nim_native_tool_stream.py`

GitHub Actions проверяет установку приватного архива на macOS, Linux и Windows, `/health`, `/admin` и `fcc-claude --version`. Наличие workflow не означает успешный прогон: смотрите фактический результат Actions. Реальная генерация с действительным ключом требует его локального ввода владельцем.

## Лицензия

Модификация [Free Claude Code](https://github.com/Alishahryar1/free-claude-code), upstream commit `9194f157af6beb663cf3e6035f9cdadb09e8917b`, автор Ali Khokhar. [AGPL-3.0-only](LICENSE), [NOTICE](NOTICE). Полные исходники этой версии доступны в этом репозитории; при предоставлении сервиса другим пользователям им также нужен доступ к соответствующим исходникам. Проект не аффилирован с NVIDIA или Anthropic, гарантия не предоставляется.

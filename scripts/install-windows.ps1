$ErrorActionPreference = "Stop"

$Repository = "kesha666-opt/opus5.5"
$Ref = if ($env:OPUS_REF) { $env:OPUS_REF } else { "main" }
$StateDir = Join-Path $HOME ".opus5.5"
$BinDir = Join-Path $HOME ".local\\bin"
$AdminUrl = "http://127.0.0.1:8182/admin"
$HealthUrl = "http://127.0.0.1:8182/health"
$PythonVersion = "3.14.7"

if ($Ref -notmatch '^[A-Za-z0-9._/-]+$') { throw "Invalid installation version." }
if (Test-NetConnection -ComputerName 127.0.0.1 -Port 8182 -InformationLevel Quiet) {
  throw "Port 8182 is already in use. Stop the existing server before installing."
}

$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("funtik-opus-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
try {
  $SourceZip = Join-Path $WorkDir "source.zip"
  Write-Host "Downloading FUNTIKSTORE Opus 5.5…"
  Invoke-WebRequest -Uri "https://github.com/$Repository/archive/$Ref.zip" -OutFile $SourceZip

  $env:Path = "$BinDir;$env:Path"
  $Uv = Get-Command uv -ErrorAction SilentlyContinue
  if (-not $Uv) {
    Write-Host "Installing the setup runtime…"
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    $Uv = Get-Command uv -ErrorAction SilentlyContinue
  }
  if (-not $Uv) {
    $UvPath = Join-Path $BinDir "uv.exe"
    if (Test-Path $UvPath) { $Uv = Get-Item $UvPath }
  }
  if (-not $Uv) { throw "uv could not be installed." }

  Write-Host "Installing FUNTIKSTORE Opus 5.5…"
  $env:UV_TOOL_DIR = Join-Path $StateDir "tools"
  $env:UV_TOOL_BIN_DIR = $BinDir
  & $Uv.Source tool install --python $PythonVersion --reinstall $SourceZip

  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Claude Code…"
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
  }
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw "Claude Code was not installed." }

  New-Item -ItemType Directory -Force -Path (Join-Path $StateDir "logs") | Out-Null
  Set-Content -Path (Join-Path $StateDir ".env") -Value "HOST=127.0.0.1`nPORT=8182`nFCC_OPEN_BROWSER=false`n" -NoNewline
  $ServerPath = Join-Path $BinDir "fcc-server.exe"
  if (-not (Test-Path $ServerPath)) {
    $Server = Get-Command fcc-server -ErrorAction Stop
    $ServerPath = $Server.Source
  }
  $LogPath = Join-Path $StateDir "logs\\launcher.log"
  $ErrorLogPath = Join-Path $StateDir "logs\\launcher-error.log"
  $ServerProcess = Start-Process -FilePath $ServerPath -RedirectStandardOutput $LogPath -RedirectStandardError $ErrorLogPath -PassThru -WindowStyle Hidden
  $Ready = $false
  1..45 | ForEach-Object {
    Start-Sleep -Seconds 1
    try { if ((Invoke-WebRequest -UseBasicParsing -Uri $HealthUrl -TimeoutSec 2).StatusCode -eq 200) { $Ready = $true; return } } catch {}
    if ($ServerProcess.HasExited) { return }
  }
  if (-not $Ready) { throw "The server did not start. See $LogPath" }
  Set-Content -Path (Join-Path $StateDir "server.pid") -Value $ServerProcess.Id
  Start-Process $AdminUrl
  Write-Host "Installed. Enter your NVIDIA API key in the opened FUNTIKSTORE page."
  Write-Host "Then open a new PowerShell window and run: fcc-opus"
} finally {
  Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}

$ErrorActionPreference = "Stop"

$Repository = "kesha666-opt/opus5.5"
$Ref = if ($env:OPUS_REF) { $env:OPUS_REF } else { "main" }
$StateDir = Join-Path $HOME ".opus5.5"
$BinDir = Join-Path $HOME ".local\bin"
$AdminUrl = "http://127.0.0.1:8182/admin"
$HealthUrl = "http://127.0.0.1:8182/health"
$PythonVersion = "3.14.7"
$ClaudeReleaseBases = @(
  "https://downloads.claude.ai/claude-code-releases",
  "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
)

function Install-ClaudeCode {
  param([string] $TemporaryDirectory)

  $Existing = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue
  if ($Existing) {
    try {
      & $Existing.Source --version | Out-Null
      if ($LASTEXITCODE -eq 0) { return }
    } catch {}
  }

  $Platform = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "win32-arm64" } else { "win32-x64" }
  $Failures = @()
  foreach ($Base in $ClaudeReleaseBases) {
    try {
      $Version = (Invoke-WebRequest -UseBasicParsing -Uri "$Base/stable" -TimeoutSec 30).Content.Trim()
      if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Release version was not plain text." }
      $Manifest = (Invoke-WebRequest -UseBasicParsing -Uri "$Base/$Version/manifest.json" -TimeoutSec 30).Content | ConvertFrom-Json
      $Release = $Manifest.platforms.$Platform
      if ($Manifest.version -ne $Version -or $Release.binary -ne "claude.exe" -or
          $Release.checksum -notmatch '^[a-fA-F0-9]{64}$' -or $Release.size -lt 1000000) {
        throw "Release manifest is invalid."
      }

      $Candidate = Join-Path $TemporaryDirectory "claude-$Platform.exe"
      Invoke-WebRequest -UseBasicParsing -Uri "$Base/$Version/$Platform/claude.exe" -OutFile $Candidate -TimeoutSec 600
      if ((Get-Item $Candidate).Length -ne [long] $Release.size) { throw "Download size does not match the official manifest." }
      $Checksum = (Get-FileHash -Algorithm SHA256 -Path $Candidate).Hash
      if ($Checksum -ne $Release.checksum) { throw "Download checksum does not match the official manifest." }

      & $Candidate --version | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Downloaded Claude Code could not start." }

      New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
      $Target = Join-Path $BinDir "claude.exe"
      Move-Item -LiteralPath $Candidate -Destination $Target -Force
      Write-Host "Claude Code $Version installed."
      return
    } catch {
      $Failures += "${Base}: $($_.Exception.Message)"
    }
  }
  throw "Claude Code could not be downloaded from its official release hosts. Check network access to downloads.claude.ai and storage.googleapis.com. $($Failures -join ' | ')"
}

if ($Ref -notmatch '^[A-Za-z0-9._/-]+$') { throw "Invalid installation version." }
if (Test-NetConnection -ComputerName 127.0.0.1 -Port 8182 -InformationLevel Quiet) {
  throw "Port 8182 is already in use. Stop the existing server before installing."
}

$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("funtik-opus-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
try {
  $SourceZip = Join-Path $WorkDir "source.zip"
  Write-Host "Downloading FUNTIKSTORE Opus 5.5…"
  Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repository/archive/$Ref.zip" -OutFile $SourceZip

  $env:Path = "$BinDir;$env:Path"
  $Uv = Get-Command uv -CommandType Application -ErrorAction SilentlyContinue
  $UvExecutable = if ($Uv) { $Uv.Source } else { $null }
  if (-not $UvExecutable) {
    Write-Host "Installing the setup runtime…"
    $UvBootstrap = (Invoke-WebRequest -UseBasicParsing -Uri "https://astral.sh/uv/install.ps1" -TimeoutSec 30).Content
    if ($UvBootstrap -notmatch '(?m)^\s*(?:param\s*\(|#|function\s|\$)' -or $UvBootstrap -match '(?i)<html|<Error>') {
      throw "The uv installer download was not PowerShell. Check access to astral.sh."
    }
    Invoke-Expression $UvBootstrap
    $Uv = Get-Command uv -CommandType Application -ErrorAction SilentlyContinue
    if ($Uv) { $UvExecutable = $Uv.Source }
  }
  if (-not $UvExecutable) {
    $UvPath = Join-Path $BinDir "uv.exe"
    if (Test-Path $UvPath) { $UvExecutable = $UvPath }
  }
  if (-not $UvExecutable) { throw "uv could not be installed." }
  & $UvExecutable --version | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "uv could not start." }

  Write-Host "Installing FUNTIKSTORE Opus 5.5…"
  $env:UV_TOOL_DIR = Join-Path $StateDir "tools"
  $env:UV_TOOL_BIN_DIR = $BinDir
  & $UvExecutable tool install --python $PythonVersion --reinstall $SourceZip
  if ($LASTEXITCODE -ne 0) { throw "Opus 5.5 package installation failed." }
  if (-not (Test-Path (Join-Path $BinDir "fcc-opus.exe"))) { throw "Opus 5.5 client was not installed." }

  Write-Host "Checking Claude Code…"
  Install-ClaudeCode -TemporaryDirectory $WorkDir

  $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (($UserPath -split ';') -notcontains $BinDir) {
    $PathEntries = @($UserPath, $BinDir) | Where-Object { $_ }
    [Environment]::SetEnvironmentVariable("Path", ($PathEntries -join ';'), "User")
  }

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
  for ($Attempt = 0; $Attempt -lt 45; $Attempt++) {
    Start-Sleep -Seconds 1
    try { if ((Invoke-WebRequest -UseBasicParsing -Uri $HealthUrl -TimeoutSec 2).StatusCode -eq 200) { $Ready = $true; break } } catch {}
    if ($ServerProcess.HasExited) { break }
  }
  if (-not $Ready) { throw "The server did not start. See $LogPath" }
  Set-Content -Path (Join-Path $StateDir "server.pid") -Value $ServerProcess.Id
  try { Start-Process $AdminUrl } catch { Write-Warning "Open $AdminUrl in your browser to finish setup." }
  Write-Host "Installed. Enter your NVIDIA API key in the opened FUNTIKSTORE page."
  Write-Host "Then open a new PowerShell window and run: fcc-opus"
} finally {
  Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}

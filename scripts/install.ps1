#Requires -Version 5.1
[CmdletBinding()]
param([string]$Ref = 'main', [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$Repository = 'kesha666-opt/opus5.5'
$Root = Join-Path $env:USERPROFILE '.opus5.5'
$Bin = Join-Path $env:USERPROFILE '.local\bin'
$Health = 'http://127.0.0.1:8182/health'
$Admin = 'http://127.0.0.1:8182/admin'
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'This installer requires Windows.' }
if ($Ref -notmatch '^[A-Za-z0-9._/-]+$') { throw 'Invalid installation version.' }
$env:PATH = "$Bin;$env:PATH"
foreach ($Name in @('fcc-server','fcc-claude')) {
 if ((Get-Command $Name -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Bin "$Name.exe"))) { throw "$Name already exists. Use a clean Windows user; no existing FCC will be replaced." }
}
$Occupied = $false
try { $null = Invoke-WebRequest $Health -UseBasicParsing -TimeoutSec 2; $Occupied = $true } catch { if ($_.Exception.Response) { $Occupied = $true } }
if ($Occupied) { throw 'Port 8182 is occupied. Existing server left untouched.' }
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item $TempDir -ItemType Directory | Out-Null
try {
 $Archive = Join-Path $TempDir 'source.zip'
 Invoke-WebRequest "https://github.com/$Repository/archive/$Ref.zip" -OutFile $Archive -UseBasicParsing
 if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Invoke-WebRequest 'https://astral.sh/uv/install.ps1' -OutFile (Join-Path $TempDir 'uv.ps1') -UseBasicParsing
  $env:UV_NO_MODIFY_PATH = '1'
  & (Join-Path $TempDir 'uv.ps1')
 }
 $env:UV_TOOL_DIR = Join-Path $Root 'tools'
 $env:UV_TOOL_BIN_DIR = $Bin
 & uv tool install $Archive
 if ($LASTEXITCODE -ne 0) { throw "Installation failed: exit $LASTEXITCODE" }
 if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Invoke-WebRequest 'https://claude.ai/install.ps1' -OutFile (Join-Path $TempDir 'claude.ps1') -UseBasicParsing
  & (Join-Path $TempDir 'claude.ps1')
 }
 if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw 'Claude Code not found after installation.' }
 New-Item (Join-Path $Root 'logs') -ItemType Directory -Force | Out-Null
 Set-Content (Join-Path $Root 'installed-ref') $Ref
 Remove-Item Env:FCC_ENV_FILE,Env:NVIDIA_NIM_API_KEY -ErrorAction SilentlyContinue
 $env:HOST = '127.0.0.1'; $env:PORT = '8182'
 $Process = Start-Process (Join-Path $Bin 'fcc-server.exe') -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $Root 'logs\launcher.log') -RedirectStandardError (Join-Path $Root 'logs\launcher-error.log')
 $Ready = $false
 for ($i = 0; $i -lt 60; $i++) {
  try { $Result = Invoke-RestMethod $Health -TimeoutSec 2; if ($Result.service -eq 'opus5.5') { $Ready = $true; break } } catch {}
  if ($Process.HasExited) { break }; Start-Sleep 1
 }
 if (-not $Ready) { throw "Server failed to start. See $Root\logs" }
 $Panel = Invoke-WebRequest $Admin -UseBasicParsing -TimeoutSec 10
 if ($Panel.Content -notmatch 'Opus 5.5' -or $Panel.Content -notmatch 'type="password"') { throw 'Opus 5.5 panel did not return the expected form.' }
 Set-Content (Join-Path $Root 'server.pid') $Process.Id
 if (-not $NoOpen) { Start-Process $Admin }
 Write-Host "Opus 5.5 installed.`nPanel: $Admin`nEnter your NVIDIA key in the panel."
} finally { Remove-Item $TempDir -Recurse -Force }

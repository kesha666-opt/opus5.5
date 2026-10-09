#Requires -Version 5.1
[CmdletBinding()]
param([string]$Ref = 'main', [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$PythonRequest = "3.14.7"
$MinUvVersion = "0.12.13"
$Repository = 'kesha666-opt/opus5.5'
$Root = Join-Path $env:USERPROFILE '.opus5.5'
$Bin = Join-Path $env:USERPROFILE '.local\bin'
$Health = 'http://127.0.0.1:8182/health'
$Admin = 'http://127.0.0.1:8182/admin'
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'This installer requires Windows.' }
if ($Ref -notmatch '^[A-Za-z0-9._/-]+$') { throw 'Invalid installation version.' }
$OriginalPath = $env:PATH
$env:PATH = "$Bin;$OriginalPath"
$OwnedInstall = Test-Path (Join-Path $Root 'tools\opus5-5\pyvenv.cfg')
foreach ($Name in @('fcc-server','fcc-claude','fcc-opus','fcc-cloud')) {
 $Command = Get-Command $Name -ErrorAction SilentlyContinue
 $Slot = Join-Path $Bin "$Name.exe"
 if ($Command -or (Test-Path $Slot)) {
  if (-not $OwnedInstall -or -not $Command -or $Command.Source -ne $Slot -or -not (Test-Path $Slot)) {
   throw "$Name already exists. Use a clean Windows user; no existing FCC will be replaced."
  }
 }
}
$Occupied = $false
try { $null = Invoke-WebRequest $Health -UseBasicParsing -TimeoutSec 2; $Occupied = $true } catch { if ($_.Exception.Response) { $Occupied = $true } }
if ($Occupied) {
 if (-not $OwnedInstall) { throw 'Port 8182 is occupied. Existing server left untouched.' }
 $HealthStatus = Invoke-RestMethod $Health -TimeoutSec 5
 if ($HealthStatus.service -ne 'opus5.5') { throw 'Port 8182 belongs to another server.' }
 $PidFile = Join-Path $Root 'server.pid'
 if (-not (Test-Path $PidFile)) { throw 'Opus 5.5 PID file is missing.' }
 $OldPid = [int](Get-Content $PidFile -Raw)
 $OldProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $OldPid"
 if (-not $OldProcess -or $OldProcess.CommandLine -notlike '*fcc-server*') { throw 'Could not safely stop the server on port 8182.' }
}
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item $TempDir -ItemType Directory | Out-Null
try {
 $Archive = Join-Path $TempDir 'source.zip'
 Invoke-WebRequest "https://github.com/$Repository/archive/$Ref.zip" -OutFile $Archive -UseBasicParsing
 $UvSupported = $false
 if (Get-Command uv -ErrorAction SilentlyContinue) {
  try { $UvSupported = [version]((& uv --version) -split ' ')[1] -ge [version]$MinUvVersion } catch {}
 }
 if (-not $UvSupported) {
  Invoke-WebRequest 'https://astral.sh/uv/install.ps1' -OutFile (Join-Path $TempDir 'uv.ps1') -UseBasicParsing
  $env:UV_NO_MODIFY_PATH = '1'
  & (Join-Path $TempDir 'uv.ps1')
 }
 $env:UV_TOOL_DIR = Join-Path $Root 'tools'
 $env:UV_TOOL_BIN_DIR = $Bin
 if ($Occupied) {
  Stop-Process -Id $OldPid
  for ($i = 0; $i -lt 20; $i++) {
   try { $null = Invoke-WebRequest $Health -UseBasicParsing -TimeoutSec 1; Start-Sleep 1 }
   catch { if (-not $_.Exception.Response) { break }; Start-Sleep 1 }
  }
  $StillOccupied = $false
  try { $null = Invoke-WebRequest $Health -UseBasicParsing -TimeoutSec 1; $StillOccupied = $true }
  catch { if ($_.Exception.Response) { $StillOccupied = $true } }
  if ($StillOccupied) { throw 'Server did not stop before update.' }
 }
 & uv tool install --python $PythonRequest --reinstall $Archive
 if ($LASTEXITCODE -ne 0) { throw "Installation failed: exit $LASTEXITCODE" }
 $UvExecutable = (Get-Command uv).Source
 $env:PATH = $OriginalPath
 try { & $UvExecutable tool update-shell } finally { $env:PATH = "$Bin;$OriginalPath" }
 if ($LASTEXITCODE -ne 0) { throw 'Could not add Opus 5.5 commands to PATH.' }
 if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Invoke-WebRequest 'https://claude.ai/install.ps1' -OutFile (Join-Path $TempDir 'claude.ps1') -UseBasicParsing
  & (Join-Path $TempDir 'claude.ps1')
 }
 if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw 'Claude Code not found after installation.' }
 New-Item (Join-Path $Root 'logs') -ItemType Directory -Force | Out-Null
 Set-Content (Join-Path $Root 'installed-ref') $Ref
 Remove-Item Env:FCC_ENV_FILE,Env:NVIDIA_NIM_API_KEY -ErrorAction SilentlyContinue
 $env:HOST = '127.0.0.1'; $env:PORT = '8182'; $env:FCC_OPEN_BROWSER = 'false'
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

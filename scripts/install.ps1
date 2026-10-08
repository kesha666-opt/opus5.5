#Requires -Version 5.1
[CmdletBinding()]
param([string]$Ref = 'main', [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$Repository = 'kesha666-opt/nova-code-bridge'
$Root = Join-Path $env:USERPROFILE '.nova-code'
$Bin = Join-Path $env:USERPROFILE '.local\bin'
$Health = 'http://127.0.0.1:8182/health'
$Admin = 'http://127.0.0.1:8182/admin'
function Assert-Exit { if ($LASTEXITCODE -ne 0) { throw "Command failed: exit $LASTEXITCODE" } }
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'This installer requires Windows.' }
$env:PATH = "$Bin;$env:PATH"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
 $Bootstrap = Join-Path $Root 'bootstrap'
 New-Item $Bootstrap -ItemType Directory -Force | Out-Null
 $Architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
 $Zip = Join-Path $Bootstrap 'gh.zip'
 Invoke-WebRequest "https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_windows_$Architecture.zip" -OutFile $Zip -UseBasicParsing
 Expand-Archive $Zip (Join-Path $Bootstrap 'gh') -Force
 Remove-Item $Zip
 $Gh = Get-ChildItem (Join-Path $Bootstrap 'gh') -Filter gh.exe -Recurse | Select-Object -First 1
 if (-not $Gh) { throw 'GitHub CLI download failed.' }
 $env:PATH = "$($Gh.DirectoryName);$env:PATH"
}
$ErrorActionPreference = 'Continue'
& gh auth status --hostname github.com 2>$null
$AuthExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($AuthExit -ne 0) { & gh auth login --hostname github.com --web --git-protocol https; Assert-Exit }
$Visibility = & gh repo view $Repository --json visibility --jq .visibility
Assert-Exit
if ($Visibility -ne 'PRIVATE') { throw 'Expected a private repository.' }
foreach ($Name in @('fcc-server','fcc-claude')) {
 if ((Get-Command $Name -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Bin "$Name.exe"))) { throw "$Name already exists. Use a clean Windows user; no existing FCC will be replaced." }
}
$Occupied = $false
try { $null = Invoke-WebRequest $Health -UseBasicParsing -TimeoutSec 2; $Occupied = $true } catch { if ($_.Exception.Response) { $Occupied = $true } }
if ($Occupied) { throw 'Port 8182 is occupied. Existing server left untouched.' }
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item $TempDir -ItemType Directory | Out-Null
try {
 $Commit = & gh api "repos/$Repository/commits/$Ref" --jq .sha
 Assert-Exit
 if ($Commit -notmatch '^[a-f0-9]{40}$') { throw 'Invalid commit returned by GitHub.' }
 # gh writes binary bytes itself; PowerShell 5 redirection corrupts ZIP archives.
 Push-Location $TempDir
 try { & $env:COMSPEC /d /c "gh api repos/$Repository/zipball/$Commit > source.zip"; Assert-Exit } finally { Pop-Location }
 if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Invoke-WebRequest 'https://astral.sh/uv/install.ps1' -OutFile (Join-Path $TempDir 'uv.ps1') -UseBasicParsing
  $env:UV_NO_MODIFY_PATH = '1'
  & (Join-Path $TempDir 'uv.ps1')
 }
 $env:UV_TOOL_DIR = Join-Path $Root 'tools'
 $env:UV_TOOL_BIN_DIR = $Bin
 & uv tool install (Join-Path $TempDir 'source.zip'); Assert-Exit
 if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Invoke-WebRequest 'https://claude.ai/install.ps1' -OutFile (Join-Path $TempDir 'claude.ps1') -UseBasicParsing
  & (Join-Path $TempDir 'claude.ps1')
 }
 if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw 'Claude Code not found after installation.' }
 New-Item (Join-Path $Root 'logs') -ItemType Directory -Force | Out-Null
 Set-Content (Join-Path $Root 'installed-commit') $Commit
 Remove-Item Env:FCC_ENV_FILE,Env:NVIDIA_NIM_API_KEY -ErrorAction SilentlyContinue
 $env:HOST = '127.0.0.1'; $env:PORT = '8182'
 $Process = Start-Process (Join-Path $Bin 'fcc-server.exe') -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $Root 'logs\launcher.log') -RedirectStandardError (Join-Path $Root 'logs\launcher-error.log')
 $Ready = $false
 for ($i = 0; $i -lt 60; $i++) {
  try { $Result = Invoke-RestMethod $Health -TimeoutSec 2; if ($Result.service -eq 'nova-code-bridge') { $Ready = $true; break } } catch {}
  if ($Process.HasExited) { break }; Start-Sleep 1
 }
 if (-not $Ready) { throw "Server failed to start. See $Root\logs" }
 $Panel = Invoke-WebRequest $Admin -UseBasicParsing -TimeoutSec 10
 if ($Panel.Content -notmatch 'Nova Code' -or $Panel.Content -notmatch 'type="password"') { throw 'Nova Code panel did not return the expected form.' }
 Set-Content (Join-Path $Root 'server.pid') $Process.Id
 if (-not $NoOpen) { Start-Process $Admin }
 Write-Host "Nova Code installed: $Commit`nPanel: $Admin`nEnter your NVIDIA key in the panel, then run: fcc-claude`nFull path: $Bin\fcc-claude.exe"
} finally { Remove-Item $TempDir -Recurse -Force }

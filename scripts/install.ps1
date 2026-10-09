#Requires -Version 5.1
[CmdletBinding()]
param([string]$Ref = 'main', [switch]$NoOpen, [switch]$ForceGitBashBootstrap)
$ErrorActionPreference = 'Stop'
$PythonRequest = "3.14.7"
$PinnedUvVersion = "0.12.17"
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
 # Claude Code's native Windows build requires Git Bash. Bootstrap it so a clean
 # Windows account does not need winget or a separate manual Git installation.
 $GitBashPath = $null
 if (-not $ForceGitBashBootstrap) { $GitBashPath = $env:CLAUDE_CODE_GIT_BASH_PATH }
 if (-not $ForceGitBashBootstrap -and (-not $GitBashPath -or -not (Test-Path $GitBashPath))) {
  $GitBashPath = @(
   (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
   (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
   (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
 }
 if ($ForceGitBashBootstrap -or -not $GitBashPath) {
  $GitRoot = Join-Path $env:LOCALAPPDATA 'Programs\Git'
  $GitInstaller = Join-Path $TempDir 'Git-64-bit.exe'
  $GitRelease = Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest'
  $GitAsset = $GitRelease.assets | Where-Object { $_.name -match '^Git-[0-9][0-9.]*-64-bit\.exe$' } | Select-Object -First 1
  if (-not $GitAsset -or $GitAsset.digest -notmatch '^sha256:[0-9a-f]{64}$') { throw 'Could not verify the latest Git for Windows release metadata.' }
  Invoke-WebRequest $GitAsset.browser_download_url -OutFile $GitInstaller -UseBasicParsing
  $GitHash = (Get-FileHash $GitInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($GitHash -ne $GitAsset.digest.Substring(7)) { throw 'Git for Windows installer checksum is invalid.' }
  $GitSignature = Get-AuthenticodeSignature $GitInstaller
  if ($GitSignature.Status -ne 'Valid') { throw 'Git for Windows installer signature is invalid.' }
  $GitArgs = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/CURRENTUSER',"/DIR=`"$GitRoot`"")
  $GitProcess = Start-Process -FilePath $GitInstaller -ArgumentList $GitArgs -Wait -PassThru -WindowStyle Hidden
  if ($GitProcess.ExitCode -ne 0) { throw "Git for Windows installation failed: exit $($GitProcess.ExitCode)" }
  $GitBashPath = Join-Path $GitRoot 'bin\bash.exe'
 }
 if (-not (Test-Path $GitBashPath)) { throw 'Git Bash was not found after installation.' }
 $env:CLAUDE_CODE_GIT_BASH_PATH = $GitBashPath
 [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $GitBashPath, 'User')
 $UvSupported = $false
 if (Get-Command uv -ErrorAction SilentlyContinue) {
  try { $UvSupported = [version]((& uv --version) -split ' ')[1] -eq [version]$PinnedUvVersion } catch {}
 }
 if (-not $UvSupported) {
  $UvArchive = Join-Path $TempDir 'uv-windows.zip'
  $UvArchiveSha256 = 'a252121d5b59398fcb137c6ea448176459a44010f33f67e0072305a637119ca7'
  Invoke-WebRequest "https://github.com/astral-sh/uv/releases/download/$PinnedUvVersion/uv-x86_64-pc-windows-msvc.zip" -OutFile $UvArchive -UseBasicParsing
  if ((Get-FileHash $UvArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $UvArchiveSha256) { throw 'uv archive checksum is invalid.' }
  $UvExtract = Join-Path $TempDir 'uv'
  Expand-Archive -Path $UvArchive -DestinationPath $UvExtract -Force
  $UvBinary = Get-ChildItem $UvExtract -Filter 'uv.exe' -File -Recurse | Select-Object -First 1
  if (-not $UvBinary) { throw 'uv.exe was not found in the verified archive.' }
  New-Item $Bin -ItemType Directory -Force | Out-Null
  Copy-Item $UvBinary.FullName (Join-Path $Bin 'uv.exe') -Force
  $UvxBinary = Get-ChildItem $UvExtract -Filter 'uvx.exe' -File -Recurse | Select-Object -First 1
  if ($UvxBinary) { Copy-Item $UvxBinary.FullName (Join-Path $Bin 'uvx.exe') -Force }
 }
 if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { throw 'uv was not found after installation.' }
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
  $ClaudeInstaller = Join-Path $TempDir 'claude.ps1'
  Invoke-WebRequest 'https://claude.ai/install.ps1' -OutFile $ClaudeInstaller -UseBasicParsing
  & ([scriptblock]::Create([IO.File]::ReadAllText($ClaudeInstaller)))
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

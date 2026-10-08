#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
# Stop Opus 5.5 yourself first; do not act on a potentially stale PID.
$env:UV_TOOL_DIR = Join-Path $env:USERPROFILE '.opus-5-5\tools'
$env:UV_TOOL_BIN_DIR = Join-Path $env:USERPROFILE '.local\bin'
& uv tool uninstall opus-5-5
if ($LASTEXITCODE -ne 0) { throw 'Uninstall failed.' }
Write-Host 'Opus 5.5 package removed. Configuration retained in ~/.opus-5-5.'

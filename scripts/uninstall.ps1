#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
# Stop Nova Code yourself first; do not act on a potentially stale PID.
$env:UV_TOOL_DIR = Join-Path $env:USERPROFILE '.nova-code\tools'
$env:UV_TOOL_BIN_DIR = Join-Path $env:USERPROFILE '.local\bin'
& uv tool uninstall nova-code-bridge
if ($LASTEXITCODE -ne 0) { throw 'Uninstall failed.' }
Write-Host 'Nova Code package removed. Configuration retained in ~/.nova-code.'

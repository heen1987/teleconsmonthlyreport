param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap"
)

$ErrorActionPreference = "Stop"

$webRoot = Join-Path $ProjectRoot "web_client"
if (-not (Test-Path (Join-Path $webRoot "package.json"))) {
  throw "package.json not found under $webRoot. Run scripts\windows_sync_local_dev.ps1 first."
}

Push-Location $webRoot
try {
  npm.cmd install
  node .\node_modules\vite\bin\vite.js build
  Write-Host "Web build complete: $(Join-Path $webRoot 'dist')"
}
finally {
  Pop-Location
}

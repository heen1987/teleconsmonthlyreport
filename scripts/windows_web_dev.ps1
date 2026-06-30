param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

$webRoot = Join-Path $ProjectRoot "web_client"
if (-not (Test-Path (Join-Path $webRoot "package.json"))) {
  throw "package.json not found under $webRoot. Run scripts\windows_sync_local_dev.ps1 first."
}

Push-Location $webRoot
try {
  if (-not (Test-Path "node_modules")) {
    npm.cmd install
  }
  node .\node_modules\vite\bin\vite.js --host 0.0.0.0 --port $Port
}
finally {
  Pop-Location
}

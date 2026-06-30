param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$appRoot = Join-Path $ProjectRoot "backend"
if (-not (Test-Path (Join-Path $appRoot ".env")) -and (Test-Path (Join-Path $appRoot ".env.example"))) {
  Copy-Item -LiteralPath (Join-Path $appRoot ".env.example") -Destination (Join-Path $appRoot ".env")
}

$python = Join-Path $appRoot ".venv-win\Scripts\python.exe"
if (-not (Test-Path $python)) {
  py -3.12 -m venv (Join-Path $appRoot ".venv-win")
  & $python -m pip install -r (Join-Path $appRoot "requirements.txt")
}

& (Join-Path $ProjectRoot "scripts\windows_apply_platform_schema.ps1") -ProjectRoot $ProjectRoot

Push-Location $appRoot
try {
  & $python -m uvicorn app.main:app --host 0.0.0.0 --port $Port
}
finally {
  Pop-Location
}

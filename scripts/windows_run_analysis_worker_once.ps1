param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap"
)

$ErrorActionPreference = "Stop"

$appRoot = Join-Path $ProjectRoot "analysis_server"
if (-not (Test-Path (Join-Path $appRoot ".env")) -and (Test-Path (Join-Path $appRoot ".env.example"))) {
  Copy-Item -LiteralPath (Join-Path $appRoot ".env.example") -Destination (Join-Path $appRoot ".env")
}

$python = Join-Path $appRoot ".venv-win\Scripts\python.exe"
if (-not (Test-Path $python)) {
  py -3.12 -m venv (Join-Path $appRoot ".venv-win")
  & $python -m pip install -r (Join-Path $appRoot "requirements.txt")
}

Push-Location $appRoot
try {
  & $python -m app.worker
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}

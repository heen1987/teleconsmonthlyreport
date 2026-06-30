param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap"
)

$ErrorActionPreference = "Stop"

$appRoot = Join-Path $ProjectRoot "collection_api"
$envPath = Join-Path $appRoot ".env"
$exampleEnv = Join-Path $appRoot ".env.example"
if (-not (Test-Path $envPath) -and (Test-Path $exampleEnv)) {
  Copy-Item -LiteralPath $exampleEnv -Destination $envPath
}

$databaseUrl = $env:DATABASE_URL
if (-not $databaseUrl -and (Test-Path $envPath)) {
  $databaseUrl = Get-Content -LiteralPath $envPath |
    Where-Object { $_ -match "^DATABASE_URL=" } |
    Select-Object -Last 1
  if ($databaseUrl) {
    $databaseUrl = $databaseUrl.Substring("DATABASE_URL=".Length)
  }
}
if (-not $databaseUrl) {
  throw "DATABASE_URL is not set."
}

$python = Join-Path $appRoot ".venv-win\Scripts\python.exe"
if (-not (Test-Path $python)) {
  py -3.12 -m venv (Join-Path $appRoot ".venv-win")
  & $python -m pip install -r (Join-Path $appRoot "requirements.txt")
}

& $python (Join-Path $ProjectRoot "scripts\run_migrations.py") `
  --database-url $databaseUrl `
  --service collection `
  --migrations-dir (Join-Path $appRoot "migrations")

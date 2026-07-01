param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [int]$Port = 8200,
  [string]$BindHost = $env:AIPMS_COLLECTION_BIND_HOST,
  [switch]$AllowPublicBind
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BindHost)) {
  $BindHost = "127.0.0.1"
}

$allowPublicByEnv = $env:AIPMS_COLLECTION_ALLOW_PUBLIC_BIND -eq "1"
if (($BindHost -eq "0.0.0.0" -or $BindHost -eq "::") -and -not ($AllowPublicBind -or $allowPublicByEnv)) {
  throw @"
Refusing to bind Collection API to a public interface.

Default external-network policy:
  - keep Collection API on 127.0.0.1
  - expose it only through VPN or an authenticated tunnel

If you intentionally need direct LAN binding, rerun with:
  powershell -ExecutionPolicy Bypass -File scripts\windows_run_collection_api.ps1 -BindHost 0.0.0.0 -AllowPublicBind
"@
}

$appRoot = Join-Path $ProjectRoot "collection_api"
if (-not (Test-Path (Join-Path $appRoot ".env")) -and (Test-Path (Join-Path $appRoot ".env.example"))) {
  Copy-Item -LiteralPath (Join-Path $appRoot ".env.example") -Destination (Join-Path $appRoot ".env")
}

$python = Join-Path $appRoot ".venv-win\Scripts\python.exe"
if (-not (Test-Path $python)) {
  py -3.12 -m venv (Join-Path $appRoot ".venv-win")
  & $python -m pip install -r (Join-Path $appRoot "requirements.txt")
}

& (Join-Path $ProjectRoot "scripts\windows_apply_collection_schema.ps1") -ProjectRoot $ProjectRoot

Push-Location $appRoot
try {
  Write-Host "Collection API bind: ${BindHost}:${Port}"
  & $python -m uvicorn app.main:app --host $BindHost --port $Port
}
finally {
  Pop-Location
}

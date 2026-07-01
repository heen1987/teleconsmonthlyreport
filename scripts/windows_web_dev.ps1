param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [int]$Port = 3000,
  [string]$BindHost = $env:AIPMS_WEB_BIND_HOST,
  [switch]$AllowPublicBind
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BindHost)) {
  $BindHost = "127.0.0.1"
}

$allowPublicByEnv = $env:AIPMS_WEB_ALLOW_PUBLIC_BIND -eq "1"
if (($BindHost -eq "0.0.0.0" -or $BindHost -eq "::") -and -not ($AllowPublicBind -or $allowPublicByEnv)) {
  throw @"
Refusing to bind Web dev server to a public interface.

Default external-network policy:
  - keep Web dev server on 127.0.0.1
  - expose it only through VPN or an authenticated tunnel

If you intentionally need direct LAN binding, rerun with:
  powershell -ExecutionPolicy Bypass -File scripts\windows_web_dev.ps1 -BindHost 0.0.0.0 -AllowPublicBind
"@
}

$webRoot = Join-Path $ProjectRoot "web_client"
if (-not (Test-Path (Join-Path $webRoot "package.json"))) {
  throw "package.json not found under $webRoot. Run scripts\windows_sync_local_dev.ps1 first."
}

Push-Location $webRoot
try {
  if (-not (Test-Path "node_modules")) {
    npm.cmd install
  }
  node .\node_modules\vite\bin\vite.js --host $BindHost --port $Port
}
finally {
  Pop-Location
}

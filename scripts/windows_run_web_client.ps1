param(
  [string]$ProjectRoot = "G:\내 드라이브\새싹교육_프로젝트\새싹교육_프로젝트 1\ai_pms_bootstrap",
  [string]$MirrorRoot = "C:\ai_pms_bootstrap_web_client",
  [string]$ApiBase = "http://127.0.0.1:8000",
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
  powershell -ExecutionPolicy Bypass -File scripts\windows_run_web_client.ps1 -BindHost 0.0.0.0 -AllowPublicBind
"@
}

$source = Join-Path $ProjectRoot "web_client"
if (-not (Test-Path -LiteralPath (Join-Path $source "package.json"))) {
  throw "missing web_client/package.json: $source"
}

New-Item -ItemType Directory -Force -Path $MirrorRoot | Out-Null
& robocopy $source $MirrorRoot /MIR /XD node_modules dist /XF desktop.ini /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -gt 7) {
  throw "robocopy failed with exit code $LASTEXITCODE"
}

Push-Location $MirrorRoot
try {
  if (-not (Test-Path -LiteralPath (Join-Path $MirrorRoot "node_modules\vite\bin\vite.js"))) {
    & cmd /c npm ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) {
      throw "npm ci failed with exit code $LASTEXITCODE"
    }
  }
}
finally {
  Pop-Location
}

$listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $Port }
foreach ($listener in $listeners) {
  $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)" -ErrorAction SilentlyContinue
  if ($process -and $process.CommandLine -match "vite|npm") {
    Stop-Process -Id $listener.OwningProcess -Force
  }
}

$stdoutLogPath = Join-Path $MirrorRoot "vite-dev.out.log"
$stderrLogPath = Join-Path $MirrorRoot "vite-dev.err.log"
$cmd = "set VITE_API_BASE=$ApiBase&& npm.cmd run dev -- --host $BindHost --port $Port"
Start-Process -FilePath "cmd.exe" `
  -ArgumentList @("/c", $cmd) `
  -WorkingDirectory $MirrorRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdoutLogPath `
  -RedirectStandardError $stderrLogPath

Write-Host "Web dev server starting:"
Write-Host "  url: http://127.0.0.1:$Port"
Write-Host "  bind: ${BindHost}:${Port}"
Write-Host "  mirror: $MirrorRoot"
Write-Host "  api: $ApiBase"
Write-Host "  stdout: $stdoutLogPath"
Write-Host "  stderr: $stderrLogPath"

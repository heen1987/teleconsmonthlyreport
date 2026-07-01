param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [int]$Port = 8200,
  [string]$BindHost = $env:AIPMS_ANALYSIS_BIND_HOST,
  [switch]$AllowPublicBind
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BindHost)) {
  $BindHost = "127.0.0.1"
}

$allowPublicByEnv = $env:AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND -eq "1"
if (($BindHost -eq "0.0.0.0" -or $BindHost -eq "::") -and -not ($AllowPublicBind -or $allowPublicByEnv)) {
  throw @"
Refusing to bind Analysis server to a public interface.

Default external-network policy:
  - keep Analysis server on 127.0.0.1
  - expose it only through VPN or an authenticated tunnel

If you intentionally need direct LAN binding, rerun with:
  powershell -ExecutionPolicy Bypass -File scripts\windows_run_analysis_server.ps1 -BindHost 0.0.0.0 -AllowPublicBind
"@
}

$appRoot = Join-Path $ProjectRoot "analysis_server"
if (-not (Test-Path (Join-Path $appRoot ".env")) -and (Test-Path (Join-Path $appRoot ".env.example"))) {
  Copy-Item -LiteralPath (Join-Path $appRoot ".env.example") -Destination (Join-Path $appRoot ".env")
  Write-Host ".env.example -> .env 복사 완료. 시크릿을 확인하세요."
}

# DB 스키마 자동 적용
$migrationsDir = Join-Path $appRoot "migrations"
$python = Join-Path $appRoot ".venv-win\Scripts\python.exe"

if (-not (Test-Path $python)) {
  Write-Host "가상환경 생성 중..."
  py -3.12 -m venv (Join-Path $appRoot ".venv-win")
  & $python -m pip install -r (Join-Path $appRoot "requirements.txt")
}

# 마이그레이션 적용 (psql 이 있을 경우)
if (Get-Command psql -ErrorAction SilentlyContinue) {
  $env_file = Join-Path $appRoot ".env"
  $db_url = (Get-Content $env_file | Where-Object { $_ -match "^DATABASE_URL=" } | Select-Object -First 1) -replace "^DATABASE_URL=", ""
  if ($db_url) {
    Get-ChildItem (Join-Path $migrationsDir "*.sql") | Sort-Object Name | ForEach-Object {
      Write-Host "마이그레이션 적용: $($_.Name)"
      psql $db_url -f $_.FullName
    }
  }
}

Push-Location $appRoot
try {
  Write-Host "Unified Analysis & Collection server bind: ${BindHost}:${Port}"
  Write-Host "  (STT/LLM Worker 가 내부에서 자동 실행됩니다)"
  & $python -m uvicorn app.main:app --host $BindHost --port $Port
}
finally {
  Pop-Location
}

param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [string]$Password    = "1234",
  [string]$Status      = "active",
  [switch]$DryRun
)

<#
.SYNOPSIS
  새싹테크솔루션 PMS 데모 데이터를 Platform DB에 적재합니다.

.DESCRIPTION
  scripts/data/saessak_company_dataset.json 을 읽어
  users (50명), resource_profiles (50개), projects (15개),
  project_members (207개) 를 Platform DB에 upsert 합니다.

  -DryRun 스위치를 사용하면 DB 반영 없이 플랜 JSON만 출력합니다.

.PARAMETER ProjectRoot
  로컬 개발 복사본 경로 (기본: %USERPROFILE%\dev\ai_pms_bootstrap)

.PARAMETER Password
  시드된 계정의 초기 비밀번호 (기본: 1234)

.PARAMETER Status
  시드된 계정의 초기 상태 (active | password_change_required)
  기본: active  — 로그인 즉시 가능

.PARAMETER DryRun
  DB에 쓰지 않고 플랜 JSON만 생성·검증합니다.

.EXAMPLE
  # 기본 실행 (로컬 dev 복사본에 적재)
  powershell -ExecutionPolicy Bypass -File .\scripts\windows_seed_demo_company.ps1

  # 드라이런 (DB 반영 없이 검증만)
  powershell -ExecutionPolicy Bypass -File .\scripts\windows_seed_demo_company.ps1 -DryRun

  # Google Drive 원본 경로에서 직접 실행
  powershell -ExecutionPolicy Bypass -File .\scripts\windows_seed_demo_company.ps1 `
    -ProjectRoot "G:\내 드라이브\새싹교육_프로젝트\새싹교육_프로젝트 1\ai_pms_bootstrap"
#>

$ErrorActionPreference = "Stop"

# ── 경로 확인 ──────────────────────────────────────────────────────────────
$backendRoot  = Join-Path $ProjectRoot "backend"
$scriptPath   = Join-Path $ProjectRoot "scripts\seed_demo_company.py"
$outputDir    = Join-Path $ProjectRoot "runtime\demo_company"
$outputPath   = Join-Path $outputDir   "latest_plan.json"
$datasetPath  = Join-Path $ProjectRoot "scripts\data\saessak_company_dataset.json"

if (-not (Test-Path $backendRoot)) {
  Write-Error "backend 폴더를 찾을 수 없습니다: $backendRoot`n로컬 개발 복사본을 먼저 동기화하세요:`n  .\scripts\windows_sync_local_dev.ps1"
}
if (-not (Test-Path $datasetPath)) {
  Write-Error "데이터셋 파일이 없습니다: $datasetPath"
}

# ── Python 인터프리터 결정 ─────────────────────────────────────────────────
$python = Join-Path $backendRoot ".venv-win\Scripts\python.exe"
if (-not (Test-Path $python)) {
  Write-Host "[seed] .venv-win 가상환경 생성 중..." -ForegroundColor Yellow
  py -3.12 -m venv (Join-Path $backendRoot ".venv-win")
  & $python -m pip install -r (Join-Path $backendRoot "requirements.txt") --quiet
}

# ── .env 보장 ─────────────────────────────────────────────────────────────
$envFile = Join-Path $backendRoot ".env"
if (-not (Test-Path $envFile)) {
  $envExample = Join-Path $backendRoot ".env.example"
  if (Test-Path $envExample) {
    Copy-Item -LiteralPath $envExample -Destination $envFile
    Write-Host "[seed] .env 파일을 .env.example에서 복사했습니다." -ForegroundColor Yellow
  } else {
    Write-Error ".env 파일이 없습니다. backend/.env 를 먼저 설정하세요."
  }
}

# ── 출력 디렉토리 생성 ────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# ── 시드 실행 ─────────────────────────────────────────────────────────────
$seedArgs = @(
  $scriptPath
  "--dataset", $datasetPath
  "--output",  $outputPath
  "--status",  $Status
  "--password", $Password
)
if (-not $DryRun) {
  $seedArgs += "--apply"
}

Write-Host ""
Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  새싹테크솔루션 PMS 데모 데이터 적재" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  dataset : $datasetPath"
Write-Host "  output  : $outputPath"
Write-Host "  password: $Password"
Write-Host "  status  : $Status"
Write-Host "  dry-run : $DryRun"
Write-Host ""

Push-Location $backendRoot
try {
  $result = & $python @seedArgs 2>&1 | Tee-Object -Variable seedOutput
  if ($LASTEXITCODE -ne 0) {
    Write-Error "seed_demo_company.py 실패 (exit $LASTEXITCODE):`n$($seedOutput -join "`n")"
  }
}
finally {
  Pop-Location
}

# ── 결과 파싱 및 출력 ─────────────────────────────────────────────────────
try {
  # stdout 마지막 줄이 JSON 결과
  $jsonLine = ($result | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
  $summary  = $jsonLine | ConvertFrom-Json

  Write-Host "══════════════════════════════════════════════" -ForegroundColor Green
  if ($DryRun) {
    Write-Host "  [DryRun] 플랜 검증 완료 — DB 반영 없음" -ForegroundColor Yellow
  } else {
    Write-Host "  적재 완료" -ForegroundColor Green
  }
  Write-Host "══════════════════════════════════════════════" -ForegroundColor Green

  if ($summary.summary) {
    $s = $summary.summary
    Write-Host "  사용자(계정)   : $($s.account_count ?? $s.headcount)명"
    Write-Host "  프로젝트       : $($s.project_count)개"
    Write-Host "  배정(멤버십)   : $($s.assignment_count)건"
    Write-Host "  총 공수        : $($s.total_planned_mm) MM"
    Write-Host "  총 인건비      : $("{0:N0}" -f [double]($s.total_labor_cost_krw))원"
  } elseif ($summary.users) {
    Write-Host "  사용자   : $($summary.users)명"
    Write-Host "  프로젝트 : $($summary.projects)개"
    Write-Host "  멤버십   : $($summary.project_memberships)건"
    Write-Host "  상태     : $($summary.status)"
  }
  Write-Host ""
  Write-Host "  플랜 파일: $outputPath"
}
catch {
  # JSON 파싱 실패해도 raw 출력은 이미 Tee-Object로 표시됨
  Write-Host "[seed] 결과 파싱 중 오류: $_" -ForegroundColor Yellow
}

Write-Host ""
if (-not $DryRun) {
  Write-Host "다음 단계: Platform API를 통해 로그인 테스트" -ForegroundColor Cyan
  Write-Host "  curl http://localhost:8000/health"
  Write-Host "  # 직원번호(E001~E050)가 login_id, 초기 비밀번호는 '$Password'"
}

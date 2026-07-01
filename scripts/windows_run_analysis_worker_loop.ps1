# ⚠️ DEPRECATED: 외부 워커 루프는 collection_api 내부로 통합되었습니다.
# 이 스크립트를 실행할 필요가 없습니다.
# collection_api 기동 시 분석 워커가 자동으로 내부에서 실행됩니다.
Write-Warning "[DEPRECATED] 외부 분석 워커 루프는 collection_api 에 내장되었습니다. 이 스크립트를 실행할 필요가 없습니다."
exit 0

param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [int]$IntervalSeconds = 5
)

$ErrorActionPreference = "Continue"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workerOnceScript = Join-Path $scriptRoot "windows_run_analysis_worker_once.ps1"

while ($true) {
  powershell -NoProfile -ExecutionPolicy Bypass -File $workerOnceScript -ProjectRoot $ProjectRoot
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Analysis worker run failed with exit code $LASTEXITCODE"
  }
  Start-Sleep -Seconds $IntervalSeconds
}

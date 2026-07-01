param(
  [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [string]$PlatformUrl = "",
  [string]$CollectionUrl = "",
  [string]$AnalysisUrl = "",
  [string]$EmployeeNo = "",
  [string]$Password = "",
  [string]$AudioFile = "",
  [int]$TimeoutSeconds = 180,
  [switch]$RunWorkerOnce
)

$ErrorActionPreference = "Stop"

function Get-Default($value, $envName, $fallback) {
  if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
  $envValue = [Environment]::GetEnvironmentVariable($envName)
  if (-not [string]::IsNullOrWhiteSpace($envValue)) { return $envValue }
  return $fallback
}

function Write-Step($message) {
  Write-Host ""
  Write-Host "== $message ==" -ForegroundColor Cyan
}

function Write-Ok($message) {
  Write-Host "  OK  $message" -ForegroundColor Green
}

function Write-Warn($message) {
  Write-Host "  WARN $message" -ForegroundColor Yellow
}

function Write-Fail($message) {
  Write-Host "  FAIL $message" -ForegroundColor Red
  exit 1
}

function Invoke-Json($url, $token = $null, $method = "GET", $body = $null) {
  $headers = @{ "Accept" = "application/json" }
  if ($token) { $headers["Authorization"] = "Bearer $token" }

  $params = @{
    Uri = $url
    Method = $method
    Headers = $headers
    UseBasicParsing = $true
    TimeoutSec = 30
  }

  if ($null -ne $body) {
    $headers["Content-Type"] = "application/json"
    $params["Body"] = ($body | ConvertTo-Json -Compress)
  }

  $response = Invoke-WebRequest @params
  return $response.Content | ConvertFrom-Json
}

function Assert-Health($label, $url) {
  try {
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Method GET "$url/health" | Out-Null
    Write-Ok "$label health: $url"
  } catch {
    Write-Fail "$label is not reachable at $url/health ($($_.Exception.Message))"
  }
}

function Get-ArrayCount($value) {
  return @($value).Count
}

$PlatformUrl = Get-Default $PlatformUrl "PLATFORM_URL" "http://127.0.0.1:8000"
$CollectionUrl = Get-Default $CollectionUrl "COLLECTION_URL" "http://127.0.0.1:8200"
$AnalysisUrl = Get-Default $AnalysisUrl "ANALYSIS_URL" "http://127.0.0.1:8100"
$EmployeeNo = Get-Default $EmployeeNo "EMPLOYEE_NO" "admin"
$Password = Get-Default $Password "PASSWORD" "admin1234"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($AudioFile)) {
  $AudioFile = Get-Default "" "AUDIO_FILE" (Join-Path $scriptDir "test_meeting_audio.wav")
}

$runWorker = $RunWorkerOnce -or ([Environment]::GetEnvironmentVariable("RUN_WORKER_ONCE") -eq "1")

if (-not (Test-Path -LiteralPath $AudioFile)) {
  Write-Step "Create test audio"
  python (Join-Path $scriptDir "create_test_audio.py") --output $AudioFile
}

$audioSizeKb = [Math]::Round((Get-Item -LiteralPath $AudioFile).Length / 1KB, 1)
Write-Ok "Test audio: $AudioFile (${audioSizeKb}KB)"

Write-Step "Service health"
Assert-Health "Platform API" $PlatformUrl
Assert-Health "Collection API" $CollectionUrl
Assert-Health "Analysis Server" $AnalysisUrl

Write-Step "Login"
$login = Invoke-Json "$PlatformUrl/users/login" -method "POST" -body @{
  employee_no = $EmployeeNo
  password = $Password
}
$token = $login.access_token
if (-not $token) { Write-Fail "Login did not return access_token" }
Write-Ok "Access token issued for $EmployeeNo"

Write-Step "Project lookup"
$projects = Invoke-Json "$PlatformUrl/projects" -token $token
$projectCount = Get-ArrayCount $projects
Write-Ok "Projects: $projectCount"
if ($projectCount -lt 1) {
  Write-Fail "No project exists. Seed demo company/project data before running this smoke."
}

$project = @($projects)[0]
$projectId = $project.project_id
$projectName = $project.name
Write-Ok "Selected project: $projectName ($projectId)"

Write-Step "Create meeting"
$meetingId = "MTG-" + [guid]::NewGuid().ToString()
$meetingTitle = "[$projectName] $(Get-Date -Format 'yyMMdd') smoke meeting"
$meeting = Invoke-Json "$PlatformUrl/meetings" -token $token -method "POST" -body @{
  meeting_id = $meetingId
  project_id = $projectId
  title = $meetingTitle
}
if ($meeting.status -notin @("created", "pending")) {
  Write-Fail "Meeting create returned unexpected status: $($meeting.status)"
}
Write-Ok "Meeting created: $meetingId"

Write-Step "Create upload session"
$session = Invoke-Json "$CollectionUrl/upload-sessions" -token $token -method "POST" -body @{
  meeting_id = $meetingId
  project_id = $projectId
  requested_by = $login.user.user_id
  file_name = (Split-Path -Leaf $AudioFile)
  content_type = "audio/wav"
}
$sessionId = $session.session_id
$uploadToken = $session.upload_token
if (-not $sessionId -or -not $uploadToken) {
  Write-Fail "Upload session did not return session_id/upload_token"
}
Write-Ok "Upload session: $sessionId"

Write-Step "Upload audio file"
$uploadUrl = "$CollectionUrl/upload-sessions/$sessionId/audio-file"
$curlArgs = @(
  "-sS",
  "-X", "POST",
  $uploadUrl,
  "-H", "Authorization: Bearer $token",
  "-H", "X-Upload-Token: $uploadToken",
  "-F", "file=@$AudioFile;type=audio/wav"
)
$uploadJson = & curl.exe @curlArgs
if ($LASTEXITCODE -ne 0) {
  Write-Fail "curl upload failed with exit code $LASTEXITCODE"
}
$upload = $uploadJson | ConvertFrom-Json
$assetId = $upload.asset_id
if (-not $assetId) {
  Write-Fail "Audio upload did not return asset_id. Response: $uploadJson"
}
Write-Ok "Audio asset: $assetId"

Write-Step "Create analysis job"
$job = Invoke-Json "$CollectionUrl/analysis-jobs" -token $token -method "POST" -body @{
  session_id = $sessionId
  asset_id = $assetId
  language = "ko"
}
$jobId = $job.job_id
if (-not $jobId) { Write-Fail "Analysis job did not return job_id" }
Write-Ok "Analysis job: $jobId ($($job.status))"

if ($runWorker) {
  Write-Step "Run analysis worker once"
  $workerScript = Join-Path $ProjectRoot "scripts\windows_run_analysis_worker_once.ps1"
  if (-not (Test-Path -LiteralPath $workerScript)) {
    Write-Fail "Worker script not found: $workerScript"
  }
  $oldCollectionUrl = [Environment]::GetEnvironmentVariable("COLLECTION_API_URL", "Process")
  [Environment]::SetEnvironmentVariable("COLLECTION_API_URL", $CollectionUrl, "Process")
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $workerScript -ProjectRoot $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
      Write-Fail "Analysis worker exited with code $LASTEXITCODE"
    }
  } finally {
    [Environment]::SetEnvironmentVariable("COLLECTION_API_URL", $oldCollectionUrl, "Process")
  }
}

Write-Step "Wait for Platform review status"
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$final = $null
do {
  Start-Sleep -Seconds 5
  $final = Invoke-Json "$PlatformUrl/meetings/$meetingId/status" -token $token
  Write-Host "  status=$($final.status)"
  if ($final.status -eq "review_required") { break }
} while ((Get-Date) -lt $deadline)

Write-Step "Final result"
$jobNow = Invoke-Json "$CollectionUrl/analysis-jobs/$jobId" -token $token
$analysisCount = Get-ArrayCount $final.analyses
Write-Host "  meeting_id              : $meetingId"
Write-Host "  meeting_status          : $($final.status)"
Write-Host "  platform_analysis_count : $analysisCount"
Write-Host "  collection_job_status   : $($jobNow.status)"
Write-Host "  callback_status         : $($jobNow.platform_callback_status)"
Write-Host "  model_name              : $($jobNow.model_name)"

if ($final.status -ne "review_required" -or $analysisCount -lt 1) {
  Write-Fail "Pipeline did not reach review_required with at least one Platform analysis."
}

Write-Ok "Meeting pipeline smoke completed through Analysis Server."

param(
  [string]$TargetRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap",
  [switch]$Mirror
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$devBase = [System.IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "dev"))
$targetFull = [System.IO.Path]::GetFullPath($TargetRoot)

if (-not $targetFull.StartsWith($devBase, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "TargetRoot must stay under $devBase"
}

New-Item -ItemType Directory -Force -Path $targetFull | Out-Null

$excludeDirs = @(
  "node_modules",
  ".venv",
  ".venv-win",
  "__pycache__",
  ".pytest_cache",
  ".mypy_cache",
  ".gradle",
  ".kotlin",
  "build",
  "dist",
  "logs",
  "runtime",
  "artifacts",
  "tmp",
  ".playwright-cli"
)

$excludeFiles = @("desktop.ini", ".DS_Store", "*.pyc", "*.pyo")

$copyMode = if ($Mirror) { @("/MIR") } else { @("/E", "/XC", "/XN", "/XO") }

$robocopyArgs = @(
  $repoRoot.Path,
  $targetFull
) + $copyMode + @(
  "/XD"
) + $excludeDirs + @(
  "/XF"
) + $excludeFiles + @(
  "/R:1",
  "/W:1",
  "/NFL",
  "/NDL",
  "/NJH",
  "/NJS",
  "/NP"
)

& robocopy @robocopyArgs | Out-Host
if ($LASTEXITCODE -gt 7) {
  throw "robocopy failed with exit code $LASTEXITCODE"
}

$localProperties = Join-Path $targetFull "android_client\local.properties"
$sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
if ((Test-Path $sdkRoot) -and ($Mirror -or -not (Test-Path $localProperties))) {
  "sdk.dir=$($sdkRoot -replace '\\','/')" | Set-Content -LiteralPath $localProperties -Encoding utf8
}

Write-Host "Local development copy ready: $targetFull"

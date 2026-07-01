param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap"
)

$ErrorActionPreference = "Stop"

$webDir = Join-Path $ProjectRoot "web_client"
$cacheDir = Join-Path $env:USERPROFILE ".cache\ai-pms\web_client"
$nodeModulesTarget = Join-Path $cacheDir "node_modules"
$nodeModulesLink = Join-Path $webDir "node_modules"

if (-not (Test-Path -LiteralPath (Join-Path $webDir "package.json"))) {
  throw "missing web_client/package.json: $webDir"
}
if (-not (Test-Path -LiteralPath (Join-Path $webDir "package-lock.json"))) {
  throw "missing web_client/package-lock.json: $webDir"
}

New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
Copy-Item -LiteralPath (Join-Path $webDir "package.json") -Destination (Join-Path $cacheDir "package.json") -Force
Copy-Item -LiteralPath (Join-Path $webDir "package-lock.json") -Destination (Join-Path $cacheDir "package-lock.json") -Force

Push-Location $cacheDir
try {
  & cmd /c npm ci --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) {
    throw "npm ci failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

$viteBin = Join-Path $nodeModulesTarget "vite\bin\vite.js"
if (-not (Test-Path -LiteralPath $viteBin)) {
  throw "Vite package is missing: $viteBin"
}

function New-NodeModulesLinkOrCopy {
  param(
    [string]$LinkPath,
    [string]$TargetPath
  )

  try {
    New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
    Write-Host "$LinkPath -> $TargetPath"
  }
  catch {
    Write-Host "Junction creation failed: $($_.Exception.Message)"
    Write-Host "Google Drive may not support Windows junctions here."
    Write-Host "Use scripts\windows_run_web_client.ps1; it runs Web from the local mirror at C:\ai_pms_bootstrap_web_client."
  }
}

if (Test-Path -LiteralPath $nodeModulesLink) {
  $item = Get-Item -LiteralPath $nodeModulesLink -Force
  $resolvedTarget = $null
  if ($item.LinkType) {
    $resolvedTarget = $item.Target
  }
  if ($item.PSIsContainer -and $resolvedTarget -eq $nodeModulesTarget) {
    Write-Host "web_client/node_modules already points to $nodeModulesTarget"
  }
  else {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupPath = Join-Path $webDir ".node_modules_broken_$stamp"
    Move-Item -LiteralPath $nodeModulesLink -Destination $backupPath
    New-NodeModulesLinkOrCopy -LinkPath $nodeModulesLink -TargetPath $nodeModulesTarget
    Write-Host "Moved existing node_modules to $backupPath"
  }
}
else {
  New-NodeModulesLinkOrCopy -LinkPath $nodeModulesLink -TargetPath $nodeModulesTarget
}

if (Test-Path -LiteralPath $nodeModulesLink) {
  Write-Host "Web dependencies ready:"
  Write-Host "$nodeModulesLink -> $nodeModulesTarget"
}
else {
  Write-Host "Web dependency cache ready:"
  Write-Host $nodeModulesTarget
  Write-Host "Project node_modules was not linked. Run scripts\windows_run_web_client.ps1 for Windows local development."
}

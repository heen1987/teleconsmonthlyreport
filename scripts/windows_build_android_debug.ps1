param(
  [string]$ProjectRoot = "$env:USERPROFILE\dev\ai_pms_bootstrap"
)

$ErrorActionPreference = "Stop"

$javaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
if (-not $javaHome) {
  $androidStudioRoots = @(
    "C:\Program Files\Android\Android Studio1\jbr",
    "C:\Program Files\Android\Android Studio\jbr"
  )
  $javaHome = $androidStudioRoots | Where-Object {
    Test-Path -LiteralPath (Join-Path $_ "bin\java.exe")
  } | Select-Object -First 1
}
if (-not $javaHome) {
  $javaHome = Join-Path $env:USERPROFILE ".jdks\temurin-21"
}
$sdkRoot = [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
if (-not $sdkRoot -and (Test-Path -LiteralPath "C:\Android\Sdk")) {
  $sdkRoot = "C:\Android\Sdk"
}
if (-not $sdkRoot) {
  $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
}
$avdHome = [Environment]::GetEnvironmentVariable("ANDROID_AVD_HOME", "User")
if (-not $avdHome -and (Test-Path -LiteralPath "C:\Android\avd")) {
  $avdHome = "C:\Android\avd"
}

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
if ($avdHome) {
  $env:ANDROID_AVD_HOME = $avdHome
}
$env:Path = "$javaHome\bin;$sdkRoot\platform-tools;$sdkRoot\emulator;$sdkRoot\cmdline-tools\latest\bin;$env:Path"

$androidRoot = Join-Path $ProjectRoot "android_client"
$localProperties = Join-Path $androidRoot "local.properties"
"sdk.dir=$($sdkRoot -replace '\\','/')" | Set-Content -LiteralPath $localProperties -Encoding utf8

Push-Location $androidRoot
try {
  .\gradlew.bat assembleDebug
  Write-Host "APK: $(Join-Path $androidRoot 'build\outputs\apk\debug\AiPmsAndroidClient-debug.apk')"
}
finally {
  Pop-Location
}

# ============================================================
# AI-PMS ?꾨줈?뺤뀡 ?쒗겕由??앹꽦 ?ㅽ겕由쏀듃 (Windows PowerShell)
# ?몃? ?ㅽ듃?뚰겕???쒕퉬?ㅻ? ?몄텧?섍린 ?꾩뿉 諛섎뱶???ㅽ뻾?섏꽭??
#
# ?ъ슜踰?(Windows 媛쒕컻 PC PowerShell):
#   cd C:\Users\...\dev\ai_pms_bootstrap
#   powershell -ExecutionPolicy Bypass -File .\scripts\windows_generate_prod_secrets.ps1
#
# ?④낵:
#   - collection_api/.env  ??PLATFORM_CALLBACK_SECRET, COLLECTION_INTERNAL_API_SECRET 援먯껜
#   - analysis_server/.env ??COLLECTION_INTERNAL_API_SECRET 援먯껜
#   - backend/.env         ??COLLECTION_CALLBACK_SECRET, COLLECTION_CALLBACK_SECRET_ID 援먯껜
#   湲곗〈 .env ?뚯씪? .env.bak ?쇰줈 諛깆뾽?⑸땲??
# ============================================================
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Write-Banner($msg) {
    Write-Host ""
    Write-Host ("?" * 50) -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host ("?" * 50) -ForegroundColor Cyan
}

Write-Banner "AI-PMS production secret generator"

# ?? ?쒕뜡 ?쒗겕由??앹꽦 (Python ?ъ슜, ?놁쑝硫?.NET RNG ?ъ슜) ??????????????????
function New-Secret {
    $pythonCmd = $null
    foreach ($cmd in @("python", "python3")) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $pythonCmd = $cmd
            break
        }
    }
    if ($pythonCmd) {
        return & $pythonCmd -c "import secrets; print(secrets.token_urlsafe(48))"
    }
    # Python ?놁쓣 寃쎌슦 .NET RNG fallback
    $bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
    return [Convert]::ToBase64String($bytes) -replace '[+/=]', { @{'+' = '-'; '/' = '_'; '=' = ''}[$_.Value] }
}

$InternalSecret  = New-Secret   # Collection API ??Analysis Worker
$CallbackSecret  = New-Secret   # Collection API ??Platform API HMAC 肄쒕갚
$CallbackSecretId = "prod-v1"

Write-Host ""
Write-Host "?앹꽦???쒗겕由?(??16?먮━留??쒖떆):" -ForegroundColor Green
Write-Host "  COLLECTION_INTERNAL_API_SECRET : <redacted>"
Write-Host "  COLLECTION_CALLBACK_SECRET     : <redacted>"
Write-Host ("  CALLBACK_SECRET_ID             : $CallbackSecretId")

# ?? ?ы띁 ?⑥닔 ????????????????????????????????????????????????????????????????
function Backup-AndCopyExample($envFile) {
    $exampleFile = "$envFile.example"
    if (-not (Test-Path $envFile)) {
        if (Test-Path $exampleFile) {
            Copy-Item $exampleFile $envFile
            Write-Host "  [?앹꽦] $envFile (.example 蹂듭궗)" -ForegroundColor Yellow
        } else {
            Write-Warning "  [?ㅻ쪟] $envFile 怨?.env.example ??紐⑤몢 ?놁뒿?덈떎. 嫄대꼫?곷땲??"
            return $false
        }
    } else {
        Copy-Item $envFile "$envFile.bak" -Force
        Write-Host "  [諛깆뾽] $envFile.bak" -ForegroundColor DarkGray
    }
    return $true
}

function Set-EnvVar($file, $key, $value) {
    $content = Get-Content $file -Raw
    if ($content -match "(?m)^$key=") {
        $content = $content -replace "(?m)^$key=.*", "$key=$value"
    } else {
        $content = $content.TrimEnd() + "`n$key=$value`n"
    }
    # BOM ?놁씠 UTF-8 ???    [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
}

# ?? Collection API .env ???????????????????????????????????????????????????????
Write-Banner "collection_api/.env ?낅뜲?댄듃"
$CollectionEnv = Join-Path $ProjectRoot "collection_api\.env"
if (Backup-AndCopyExample $CollectionEnv) {
    Set-EnvVar $CollectionEnv "PLATFORM_CALLBACK_SECRET"        $CallbackSecret
    Set-EnvVar $CollectionEnv "PLATFORM_CALLBACK_SECRET_ID"     $CallbackSecretId
    Set-EnvVar $CollectionEnv "COLLECTION_INTERNAL_API_SECRET"  $InternalSecret
    Write-Host "  ?꾨즺: $CollectionEnv" -ForegroundColor Green
}

# ?? Analysis Server .env ??????????????????????????????????????????????????????
Write-Banner "analysis_server/.env ?낅뜲?댄듃"
$AnalysisEnv = Join-Path $ProjectRoot "analysis_server\.env"
if (Backup-AndCopyExample $AnalysisEnv) {
    Set-EnvVar $AnalysisEnv "COLLECTION_INTERNAL_API_SECRET"    $InternalSecret
    Write-Host "  ?꾨즺: $AnalysisEnv" -ForegroundColor Green
}

# ?? Platform API backend .env ?????????????????????????????????????????????????
Write-Banner "backend/.env ?낅뜲?댄듃"
$BackendEnv = Join-Path $ProjectRoot "backend\.env"
if (Backup-AndCopyExample $BackendEnv) {
    Set-EnvVar $BackendEnv "COLLECTION_CALLBACK_SECRET"         $CallbackSecret
    Set-EnvVar $BackendEnv "COLLECTION_CALLBACK_SECRET_ID"      $CallbackSecretId
    Write-Host "  ?꾨즺: $BackendEnv" -ForegroundColor Green
}

# ?? ?꾨즺 ?덈궡 ?????????????????????????????????????????????????????????????????
Write-Banner "?꾨즺"
Write-Host ""
Write-Host "  ??3媛??쒕퉬??.env ?뚯씪?????쒗겕由우씠 ?곸슜?먯뒿?덈떎." -ForegroundColor Green
Write-Host ""
Write-Host "  ?좑툘  ??媛믩뱾? Mac mini .env ?먮룄 ?숈씪?섍쾶 蹂듭궗?댁빞 ?⑸땲??" -ForegroundColor Yellow
Write-Host "      Mac mini ?먯꽌 scripts/generate_prod_secrets.sh 瑜?蹂꾨룄濡??ㅽ뻾?섍굅??"
Write-Host "      ?꾩쓽 ?쒗겕由?媛믪쓣 Mac mini .env ???섎룞?쇰줈 遺숈뿬?ｌ쑝?몄슂."
Write-Host ""
Write-Host "  ?뮕 .env.bak ?뚯씪? ?몄젣???댁쟾 ?ㅼ젙 蹂듭썝???ъ슜?????덉뒿?덈떎." -ForegroundColor DarkGray
Write-Host ""

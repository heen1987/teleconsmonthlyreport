#!/usr/bin/env bash
# ============================================================
# AI-PMS 회의 파이프라인 전체 흐름 스모크 테스트
#
# 흐름: 로그인 → 프로젝트 조회 → 회의 생성 (자동 제목) →
#       Upload Session → 파일 업로드 → Analysis Job 생성 →
#       Job 상태 대기 → Platform API 결과 조회
#
# 사용법:
#   bash scripts/smoke_meeting_pipeline.sh
#   EMPLOYEE_NO=admin PASSWORD=yourpw bash scripts/smoke_meeting_pipeline.sh
#
# 선행: services가 모두 실행 중이어야 합니다.
#   bash scripts/run_platform_backend.sh
#   bash scripts/run_collection_api.sh
#   (Analysis Worker는 없어도 job 생성까지는 검증 가능)
# ============================================================
set -euo pipefail

PLATFORM_URL="${PLATFORM_URL:-http://127.0.0.1:8000}"
COLLECTION_URL="${COLLECTION_URL:-http://127.0.0.1:8200}"
EMPLOYEE_NO="${EMPLOYEE_NO:-admin}"
PASSWORD="${PASSWORD:-1234}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_FILE="${AUDIO_FILE:-$SCRIPT_DIR/test_meeting_audio.wav}"

ok()   { echo "  ✅ $*"; }
fail() { echo "  ❌ $*"; exit 1; }
step() { echo ""; echo "── $* ──────────────────────────────────────"; }

# ── 선행: WAV 파일이 없으면 자동 생성 ────────────────────────────────────────
if [[ ! -f "$AUDIO_FILE" ]]; then
    step "테스트 WAV 생성"
    python3 "$SCRIPT_DIR/create_test_audio.py" --output "$AUDIO_FILE"
fi
ok "테스트 WAV: $AUDIO_FILE ($(du -h "$AUDIO_FILE" | cut -f1))"

# ── 헬퍼 ──────────────────────────────────────────────────────────────────────
json_field() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d$1)" 2>/dev/null; }
today() { date "+%y%m%d"; }

# ── 1. 헬스 체크 ──────────────────────────────────────────────────────────────
step "헬스 체크"
curl -sf "$PLATFORM_URL/health"   > /dev/null && ok "Platform API ($PLATFORM_URL)" || fail "Platform API 응답 없음"
curl -sf "$COLLECTION_URL/health" > /dev/null && ok "Collection API ($COLLECTION_URL)" || fail "Collection API 응답 없음"

# ── 2. 로그인 ─────────────────────────────────────────────────────────────────
step "로그인  ($EMPLOYEE_NO)"
LOGIN=$(curl -sf -X POST "$PLATFORM_URL/users/login" \
    -H "Content-Type: application/json" \
    -d "{\"employee_no\":\"$EMPLOYEE_NO\",\"password\":\"$PASSWORD\"}")
TOKEN=$(echo "$LOGIN" | json_field '["access_token"]')
[[ -n "$TOKEN" ]] && ok "access_token 발급" || fail "로그인 실패: $LOGIN"

AUTH="-H \"Authorization: Bearer $TOKEN\""
eval "CURL_AUTH=(curl -sf -H 'Authorization: Bearer $TOKEN')"

# ── 3. 프로젝트 조회 ──────────────────────────────────────────────────────────
step "프로젝트 목록 조회"
PROJECTS=$("${CURL_AUTH[@]}" "$PLATFORM_URL/projects")
PROJECT_COUNT=$(echo "$PROJECTS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
ok "프로젝트 ${PROJECT_COUNT}개"

if [[ "$PROJECT_COUNT" -eq 0 ]]; then
    echo "  ⚠️  프로젝트가 없습니다. 웹에서 프로젝트를 먼저 생성하세요."
    echo "     테스트 종료 (회의 생성 전까지만 검증됨)"
    exit 0
fi

PROJECT_ID=$(echo "$PROJECTS" | python3 -c "import sys,json; p=json.load(sys.stdin)[0]; print(p['project_id'])")
PROJECT_NAME=$(echo "$PROJECTS" | python3 -c "import sys,json; p=json.load(sys.stdin)[0]; print(p['name'])")
ok "선택 프로젝트: $PROJECT_NAME ($PROJECT_ID)"

# ── 4. 회의 제목 자동 생성 ──────────────────────────────────────────────────
MEETING_TITLE="[$PROJECT_NAME] $(today) 회의"
MEETING_ID="MTG-$(python3 -c 'import uuid; print(uuid.uuid4())')"
ok "자동 제목: $MEETING_TITLE"
ok "Meeting ID: $MEETING_ID"

# ── 5. 회의 생성 (Platform API) ───────────────────────────────────────────────
step "회의 생성"
MEETING=$("${CURL_AUTH[@]}" -X POST "$PLATFORM_URL/meetings" \
    -H "Content-Type: application/json" \
    -d "{\"meeting_id\":\"$MEETING_ID\",\"project_id\":\"$PROJECT_ID\",\"title\":\"$MEETING_TITLE\"}")
MEETING_STATUS=$(echo "$MEETING" | json_field '["status"]')
[[ "$MEETING_STATUS" == "pending" || "$MEETING_STATUS" == "created" ]] && ok "meeting created (status=$MEETING_STATUS)" || fail "회의 생성 실패: $MEETING"

# ── 6. Upload Session 생성 (Collection API) ────────────────────────────────
step "Upload Session 생성"
SESSION=$("${CURL_AUTH[@]}" -X POST "$COLLECTION_URL/upload-sessions" \
    -H "Content-Type: application/json" \
    -d "{\"meeting_id\":\"$MEETING_ID\",\"project_id\":\"$PROJECT_ID\",\"segment_index\":0}")
SESSION_ID=$(echo "$SESSION" | json_field '["session_id"]')
UPLOAD_TOKEN=$(echo "$SESSION" | json_field '["upload_token"]')
[[ -n "$UPLOAD_TOKEN" ]] && ok "upload_token issued" || fail "Upload Session upload_token missing: $SESSION"
[[ -n "$SESSION_ID" ]] && ok "session_id=$SESSION_ID" || fail "Upload Session 생성 실패: $SESSION"

# ── 7. 파일 업로드 ────────────────────────────────────────────────────────────
step "파일 업로드  ($(basename "$AUDIO_FILE"))"
UPLOAD=$("${CURL_AUTH[@]}" -X POST "$COLLECTION_URL/upload-sessions/$SESSION_ID/audio-file" \
    -H "X-Upload-Token: $UPLOAD_TOKEN" \
    -F "file=@$AUDIO_FILE;type=audio/wav")
ASSET_ID=$(echo "$UPLOAD" | json_field '["asset_id"]')
[[ -n "$ASSET_ID" ]] && ok "asset_id=$ASSET_ID" || fail "파일 업로드 실패: $UPLOAD"

# ── 8. Analysis Job 생성 ──────────────────────────────────────────────────────
step "Analysis Job 생성"
JOB=$("${CURL_AUTH[@]}" -X POST "$COLLECTION_URL/analysis-jobs" \
    -H "Content-Type: application/json" \
    -d "{\"session_id\":\"$SESSION_ID\",\"asset_id\":\"$ASSET_ID\",\"meeting_id\":\"$MEETING_ID\",\"project_id\":\"$PROJECT_ID\",\"segment_index\":0}")
JOB_ID=$(echo "$JOB" | json_field '["job_id"]')
JOB_STATUS=$(echo "$JOB" | json_field '["status"]')
[[ -n "$JOB_ID" ]] && ok "job_id=$JOB_ID  status=$JOB_STATUS" || fail "Job 생성 실패: $JOB"

# ── 9. Analysis Worker 대기 (선택) ────────────────────────────────────────────
step "Worker 처리 대기 (최대 120초)"
ANALYSIS_URL="${ANALYSIS_URL:-http://127.0.0.1:8100}"
if curl -sf "$ANALYSIS_URL/health" > /dev/null 2>&1; then
    ok "Analysis Server 감지됨 — Worker 처리 완료까지 대기합니다"
    for i in $(seq 1 24); do
        sleep 5
        STATUS_NOW=$("${CURL_AUTH[@]}" "$PLATFORM_URL/meetings/$MEETING_ID/status" 2>/dev/null | json_field '["status"]' 2>/dev/null || echo "pending")
        echo "    [${i}] meeting status = $STATUS_NOW"
        if [[ "$STATUS_NOW" == "review_required" ]]; then
            ok "분석 완료! (status=review_required)"
            break
        fi
    done
else
    echo "  ⚠️  Analysis Server($ANALYSIS_URL)가 실행 중이 아닙니다."
    echo "     Job은 정상 생성됐습니다. Worker를 실행하면 STT·LLM 분석이 진행됩니다."
fi

# ── 10. 최종 상태 확인 ────────────────────────────────────────────────────────
step "최종 회의 상태"
FINAL=$("${CURL_AUTH[@]}" "$PLATFORM_URL/meetings/$MEETING_ID/status" 2>/dev/null || echo "{}")
echo "  $FINAL" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(f'  meeting_id : {d.get(\"meeting_id\", \"-\")}')
    print(f'  title      : {d.get(\"title\", \"-\")}')
    print(f'  status     : {d.get(\"status\", \"-\")}')
    analyses = d.get(\"analyses\", [])
    print(f'  analyses   : {len(analyses)}개')
except Exception as e:
    print(f'  (JSON 파싱 오류: {e})')
" 2>/dev/null || true

echo ""
echo "  ✅ 파이프라인 스모크 테스트 완료"
echo "     회의 제목: $MEETING_TITLE"
echo "     Meeting ID: $MEETING_ID"
echo ""

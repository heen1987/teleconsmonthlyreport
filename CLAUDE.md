# AI-PMS Bootstrap — CLAUDE.md

> **AI 코딩 도구 전용 프로젝트 지침서.**  
> Claude Code, Codex, Cursor, Copilot 등 모든 AI 어시스턴트는 이 파일을 먼저 읽고 작업하세요.

---

## 1. 프로젝트 개요

**프로젝트명:** 로컬 LLM 기반 AI-PMS 및 회의정보 지능화 모듈

회의 음성 녹음 → STT/LLM 분석 → 회의록 검토·승인 → PMS 반영 파이프라인을 구현하는 PoC.  
모든 데이터는 `Project_ID` 를 중심 키로 연결된다.

### 서비스 구성

| 서비스 | 경로 | 역할 | 기본 포트 |
|---|---|---|---|
| Platform API | `backend/` | 사용자·프로젝트·회의·승인·PMS 반영 | 8000 |
| Collection & Analysis | `collection_api/` | 업로드·분석 job·STT(Whisper)·LLM(Ollama) | 8200 |
| React Web | `web_client/` | 회의록 검토·승인·관리자 콘솔 | 3000 |
| Android App | `android_client/` | 녹음·업로드·상태 확인 | — |

> ⚠️ `analysis_server/`는 **Deprecated**. STT·LLM 처리는 `collection_api/` 내 asyncio 백그라운드 워커로 통합됨.

---

## 2. 기술 스택

### Backend (Platform API)
- **FastAPI** + **psycopg3** + **PostgreSQL 16** + **pgvector**
- 인증: Bearer token (SHA-256 해시로 DB 저장)
- 비밀번호: bcrypt hash
- 마이그레이션: `backend/migrations/*.sql` (자동 적용)

### Frontend (React Web)
- **React 19** + **TypeScript** + **Vite**
- 스타일: CSS (`src/styles.css` 단일 파일)
- 아이콘: `lucide-react`
- 상태관리: React 내장 hooks (Redux 없음)

### Android
- **Kotlin** + **Ktor client** + **coroutines**
- UI: Programmatic View (XML 레이아웃 없음 — 향후 개선 대상)
- 빌드: Gradle 8 + Android SDK 35

### Analysis
- **Ollama** (Qwen3 4B/8B)
- **Whisper.cpp** (`models/whisper/ggml-small.bin`)

---

## 3. 디렉토리 구조

```
ai_pms_bootstrap/
├── backend/
│   ├── app/
│   │   ├── core/config.py        # 환경변수 설정 (Settings)
│   │   ├── db/session.py         # get_connection() — sync psycopg3
│   │   ├── domain/statuses.py    # 상태 StrEnum 정의
│   │   ├── routers/              # FastAPI 라우터 (파일당 도메인 1개)
│   │   │   ├── users.py          # 인증, 비밀번호 변경/재설정
│   │   │   ├── admin_users.py    # 관리자 전용 사용자 CRUD
│   │   │   ├── projects.py       # 프로젝트·구성원
│   │   │   ├── meetings.py       # 회의·분석결과·검토
│   │   │   ├── approvals.py      # 회의록 승인
│   │   │   ├── distributions.py  # 이메일 배포·재시도
│   │   │   ├── resources.py      # 자원 Pool·배정·비용·리스크 승격
│   │   │   ├── tasks.py          # 업무·지연 리스크 승격
│   │   │   ├── dashboard.py      # 대시보드 요약
│   │   │   ├── operations.py     # 운영 큐 상태
│   │   │   └── collection_callbacks.py  # Analysis Worker 콜백
│   │   ├── schemas/              # Pydantic 요청/응답 스키마
│   │   ├── services/
│   │   │   ├── auth_tokens.py    # issue/require/revoke 토큰
│   │   │   ├── passwords.py      # bcrypt hash/verify
│   │   │   └── password_resets.py
│   │   └── main.py               # FastAPI 앱 진입점·CORS 설정
│   ├── migrations/               # 순번 SQL 마이그레이션
│   └── .env                      # DB URL, 시크릿 (버전관리 제외)
│
├── web_client/
│   └── src/
│       ├── types/index.ts        # ★ 모든 TypeScript 타입 정의
│       ├── api/client.ts         # ★ API 레이어 (authApi, projectsApi 등)
│       ├── hooks/useAuth.ts      # ★ 인증 커스텀 훅
│       ├── main.tsx              # App 컴포넌트 + 하위 컴포넌트 (분리 진행 중)
│       └── styles.css            # 전체 스타일
│
├── android_client/
│   └── src/main/java/com/aipms/
│       ├── MainActivity.kt       # 단일 Activity (MVVM 분리 예정)
│       ├── client/               # KtorAiPmsApiClient, AiPmsContracts, Repository
│       └── recording/            # SegmentedRecorder (10분 자동분할·자동업로드)
│
├── collection_api/               # Platform API와 동일한 구조
├── analysis_server/              # Ollama/Whisper 연동 서버
└── scripts/
    ├── generate_prod_secrets.sh          # Mac mini용 프로덕션 시크릿 생성
    ├── windows_generate_prod_secrets.ps1 # Windows용 프로덕션 시크릿 생성
    └── ...                               # 실행·빌드·스모크 테스트 스크립트
```

---

## 4. 실행 방법

```bash
# ⚠️ 외부 네트워크 최초 배포 전: 프로덕션 시크릿 생성 (Mac mini)
bash scripts/generate_prod_secrets.sh
# → 3개 .env 파일 자동 업데이트 후 3개 서비스 재시작 필요

# 서비스 전체 시작 (Mac mini 기준)
cd ai_pms_bootstrap
bash scripts/run_postgres.sh
bash scripts/run_collection_api.sh
bash scripts/run_analysis_server.sh
bash scripts/run_analysis_worker_loop.sh
bash scripts/run_platform_backend.sh

# React 웹 클라이언트
cd web_client && npm install && npm run dev

# 상태 확인
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8200/health
curl http://127.0.0.1:8100/health
```

### Windows PC 기준

Google Drive 경로에서는 `node_modules` 잠금이 발생할 수 있으므로, Windows 개발은 로컬 개발본에서 실행한다.

```powershell
cd C:\Users\김희섭\dev\ai_pms_bootstrap

# ⚠️ 외부 네트워크 최초 배포 전: 프로덕션 시크릿 생성 (Windows)
powershell -ExecutionPolicy Bypass -File .\scripts\windows_generate_prod_secrets.ps1
# → 생성된 시크릿을 Mac mini .env 파일에도 동일하게 복사해야 함

# PostgreSQL
docker compose up -d db

# Platform API / Analysis API / Collection API
powershell -ExecutionPolicy Bypass -File .\scripts\windows_run_platform_backend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\windows_run_analysis_server.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\windows_run_analysis_worker_loop.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\windows_run_collection_api.ps1

# React Web
powershell -ExecutionPolicy Bypass -File .\scripts\windows_web_dev.ps1

# Android Debug APK
powershell -ExecutionPolicy Bypass -File .\scripts\windows_build_android_debug.ps1
```

---

## 5. 핵심 아키텍처 원칙

1. **LLM 결과는 항상 후보·초안** — 사람 승인 없이 PMS 공식 데이터로 자동 반영하지 않는다.
2. **`Project_ID` 중심 연결** — 회의·업무·자원·비용·리스크·지식이 모두 `project_id`로 연결된다.
3. **Collection ↔ Platform 분리** — 파일 업로드와 분석 job은 Collection API, 승인과 PMS 반영은 Platform API 책임.
4. **Worker Pull 방식** — Mac mini Analysis Worker가 Collection API에서 job을 pull (push 아님).
5. **감사로그 필수** — 주요 변경(승인, 배포, 리스크 승격, 비밀번호 재설정)은 `audit_logs` 테이블에 기록.

---

## 6. 코딩 컨벤션

### Backend (Python)
```python
# ✅ 인증이 필요한 모든 엔드포인트에 Depends 사용
@router.get("/some-resource")
def get_resource(current_user: dict = Depends(require_active_user)):
    ...

# ✅ 에러 메시지는 계정 상태를 노출하지 않음
raise HTTPException(status_code=403, detail="Access denied")  # ✅
raise HTTPException(status_code=403, detail=f"Account is {status}")  # ❌

# ✅ 본인 리소스 변경 시 반드시 ownership 검증
if current_user["employee_no"] != payload.employee_no:
    raise HTTPException(status_code=403, detail="Cannot change another user's password")

# ✅ 감사로그는 try/finally가 아닌 같은 transaction 안에서 INSERT
cursor.execute("INSERT INTO audit_logs ...")

# ⚠️ DB 호출은 현재 sync psycopg3 — 향후 async로 전환 예정
# async def 라우터 안에서 with get_connection() 사용은 이벤트루프 블로킹 유발
```

### Frontend (React/TypeScript)
```typescript
// ✅ 타입은 src/types/index.ts에서 import
import type { Project, ReviewPackage } from "../types";

// ✅ API 호출은 src/api/client.ts의 도메인별 객체 사용
import { projectsApi, meetingsApi } from "../api/client";

// ✅ 인증 상태는 useAuth 훅 사용
import { useAuth } from "../hooks/useAuth";

// ✅ 딥 클론은 structuredClone 사용 (JSON.parse/stringify 대신)
const copy = structuredClone(original);

// ✅ 객체 동등 비교는 lodash isEqual (JSON.stringify 키순서 불일치 방지)
import { isEqual } from "lodash";
if (!isEqual(a, b)) { ... }

// ❌ localStorage 직접 사용 금지 — useAuth 훅 내부에서만 접근
localStorage.setItem(...)  // ❌
```

### Android (Kotlin)
```kotlin
// ✅ 모든 API 호출은 Dispatchers.IO에서 실행
withContext(Dispatchers.IO) { client().someApiCall() }

// ✅ UI 업데이트는 runOnUiThread 또는 Main dispatcher
withContext(Dispatchers.Main) { setStatus("완료") }

// ✅ 새 화면을 추가할 때 showScreen() when 블록에 분기 추가
private fun showScreen(screen: AppScreen) {
    contentHost.addView(when (screen) {
        AppScreen.NEW_SCREEN -> newScreen()
        // ...
    })
}

// ⚠️ client()는 매 호출 시 새 객체 생성 — 싱글턴 패턴으로 개선 예정
```

---

## 7. 인증 흐름

```
로그인 → access_token 발급 (DB hash 저장)
    → 초기 비밀번호 변경 강제 (password_change_required 상태)
    → 변경 완료 → active 상태
    → 이후 모든 API: Authorization: Bearer <token>

로그아웃 → token revoke_at 설정
토큰 만료 → 401 반환 → 클라이언트에서 재로그인 유도

관리자만 /admin/users 경로 접근 가능 (require_admin_user Depends)
```

---

## 8. 주요 데이터 흐름

```
Android 녹음 (SegmentedRecorder — 10분 자동분할)
  [녹음 시작 시]
  → POST /meetings                          (Platform API — meeting_id 생성)
  [10분마다 세그먼트 완성 시 자동 반복]
  → POST /collection/upload-sessions        (Collection API)
  → PUT  /collection/upload-sessions/{id}/file
  → POST /collection/analysis-jobs          (job 생성, meeting_id 연결)
  [녹음 중 백그라운드에서 반복]
  → Mac mini Worker: GET  /collection/analysis-jobs/next (pull)
  → Mac mini Worker: STT + LLM 분석
  → Mac mini Worker: POST /collection/analysis-jobs/{id}/complete
  → Collection → Platform callback: POST /integrations/collection/jobs/{id}/complete
  → Platform: meeting_analyses 테이블에 세그먼트별 초안 저장 (하나의 meeting에 N개 분석)

  외부 파일 업로드 (uploadButton 탭)
  → 파일 선택 → POST /meetings → 위 흐름과 동일

Web 검토
  → GET  /meetings/{id}/review-package
  → PUT  /meetings/analyses/{id}/review-edits   (수정 저장)
  → POST /approvals/meeting-analyses/{id}/approve (승인)
  → POST /meetings/{id}/distribute              (이메일 배포)
  → PMS: tasks, risks, resource_demands, knowledge_items 생성
```

---

## 9. 알려진 기술 부채 (TODO)

| 항목 | 파일 | 우선순위 |
|---|---|---|
| DB 호출 async 전환 | `backend/app/db/session.py` | 🟡 중간 |
| 라우트별 화면/상태 분리 | `web_client/src/AppRouter.tsx`, `web_client/src/main.tsx` | 🟡 중간 |
| App 컴포넌트 분리 | `web_client/src/main.tsx` | 🟡 중간 |
| onActivityResult → ActivityResultLauncher 마이그레이션 | `android_client/.../MainActivity.kt` | 🟡 중간 |
| MeetingUploadRepository 업로드 실패 시 orphan 세션/에셋 정리 | `android_client/.../client/` | 🟡 중간 |
| Android MVVM 적용 | `android_client/.../MainActivity.kt` | 🟢 낮음 |
| Android XML 레이아웃 전환 | `android_client/` | 🟢 낮음 |
| Jetpack Compose 전환 | `android_client/` | 🟢 낮음 |
| token refresh 로직 | `web_client/`, `android_client/` | 🟡 중간 |

---

## 10. 데이터베이스 마이그레이션 규칙

- 새 마이그레이션: `backend/migrations/NNNN_description.sql` 형식
- 마이그레이션은 멱등성 보장 (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`)
- `schema_migrations` 테이블로 적용 여부 추적
- 서비스 시작 스크립트가 자동으로 미적용 마이그레이션 실행
- **절대 기존 마이그레이션 파일 수정 금지** — 새 파일로 추가

---

## 11. 보안 체크리스트

AI가 코드를 수정하기 전 반드시 확인:

- [ ] 모든 인증 필요 엔드포인트에 `Depends(require_active_user)` 또는 `Depends(require_admin_user)` 있음
- [ ] 에러 메시지에 계정 상태, 내부 경로, DB 오류 원문이 포함되지 않음
- [ ] 타인 리소스 변경 시 ownership 검증(`current_user` vs `payload` 비교) 있음
- [ ] 비밀번호 평문 저장 없음 (`hash_password()` 사용)
- [ ] 감사로그 INSERT 누락 없음 (승인·배포·비밀번호 변경·리스크 승격)
- [ ] SQL 쿼리에 파라미터 바인딩 사용 (`%s`, f-string 직접 삽입 금지)

---

## 12. 스모크 테스트 명령

```bash
cd ai_pms_bootstrap

# 전체 연결 확인
bash scripts/smoke_analysis_connection.sh

# 인증 토큰 테스트
bash scripts/smoke_auth_tokens.sh

# 관리자 사용자 등록 테스트
bash scripts/smoke_admin_user_registration.sh

# 오디오 업로드 → STT → LLM → 콜백 전체 흐름
bash scripts/smoke_audio_upload_job.sh

# 자원 배정/충돌 테스트
bash scripts/smoke_resource_allocation.sh

# MVP 정적 검증
bash scripts/verify_mvp_static.sh
```

---

## 13. 환경변수 참고

| 변수 | 위치 | 설명 |
|---|---|---|
| `DATABASE_URL` | `backend/.env` | PostgreSQL 연결 문자열 |
| `AIPMS_SECRET_KEY` | `backend/.env` | 토큰 서명 시크릿 |
| `ACCESS_TOKEN_TTL_SECONDS` | `backend/.env` | 토큰 만료 시간 (기본 86400) |
| `PASSWORD_RESET_DELIVERY_MODE` | `backend/.env` | `dev_log` 또는 `smtp` |
| `AIPMS_PLATFORM_BASE_URL` | Android `BuildConfig` | Platform API URL |
| `AIPMS_COLLECTION_BASE_URL` | Android `BuildConfig` | Collection API URL |
| `VITE_API_BASE` | `web_client/.env` | React에서 API_BASE 오버라이드 |
| `OLLAMA_MODEL` | `analysis_server/.env` | 사용할 LLM 모델명 |
| `OLLAMA_TIMEOUT_SECONDS` | `analysis_server/.env` | Ollama HTTP 타임아웃 (기본 180) |
| `WHISPER_MODEL_PATH` | `analysis_server/.env` | Whisper 모델 경로 |
| `COLLECTION_INTERNAL_API_SECRET` | `collection_api/.env`, `analysis_server/.env` | Worker ↔ Collection 인증 시크릿 |
| `PLATFORM_CALLBACK_SECRET` | `collection_api/.env`, `backend/.env` | Collection → Platform HMAC 시크릿 |

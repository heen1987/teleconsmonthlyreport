# Modular Backend Redefinition

Last updated: 2026-06-29

## Decision

초기 MVP는 물리적으로 서버를 과도하게 분리하지 않는다. 앱과 React Web은 API를 통해 백엔드에 접근하지만, 백엔드 내부 구현은 기능 모듈 기준으로 나눈다. STT/LLM 분석처럼 처리 시간이 긴 작업만 로컬 LLM AI 분석 Worker가 비동기 Job 방식으로 수행한다.

즉, API를 없애는 것이 아니라 API의 위치를 외부 접점으로 한정한다.

```text
Android App / React Web
        |
        v
AI-PMS Backend API
  - auth/user module
  - project module
  - meeting module
  - upload/collection module
  - analysis job module
  - minutes review/approval module
  - distribution module
  - PMS reflection module
  - audit log module
        |
        v
Async Job Queue / Job Table
        |
        v
Local LLM AI Analysis Worker
  - STT conversion
  - meeting content analysis
  - analysis JSON generation
  - JSON Schema validation
```

## Terminology Mapping

| Previous Expression | Revised Expression | Meaning |
|---|---|---|
| Collection API | 수집·업로드 모듈 | 업로드 세션, 파일 저장, 파일 검증, 분석 Job 생성 |
| Platform API | 플랫폼 데이터 관리 모듈 | 사용자, 프로젝트, 회의, 회의록, 승인, 배포, PMS 반영 |
| Analysis Server | 로컬 LLM AI 분석 Worker | STT/LLM 분석을 비동기 작업으로 수행 |
| Collection API와 Platform API 분리 | Backend 내부 모듈 분리 | 물리적 서버 분리가 아니라 책임 단위 분리 |
| API 간 연계 | 내부 모듈 호출 + 비동기 Job | 불필요한 네트워크 호출 최소화 |
| 상태 callback | 내부 이벤트 또는 상태 테이블 갱신 | 초기 MVP는 단일 DB 상태관리로 단순화 가능 |

## Role Boundary

| 구분 | 역할 | 책임 |
|---|---|---|
| 앱 | 회의정보 입력 채널 | 프로젝트 선택, 회의 녹음·업로드, 처리상태 확인 |
| React Web | 업무 검토 채널 | 회의록 검토·수정·승인, 배포, PMS 반영 |
| AI-PMS Backend | 업무 데이터 중심 처리 | 사용자, 프로젝트, 회의, 회의록, 승인, 배포, 상태조회, 감사로그 관리 |
| 수집·업로드 모듈 | 파일 수집 처리 | 업로드 세션, 음성파일 저장, 파일 검증 |
| 분석작업 관리 모듈 | 분석 운영 처리 | 분석 Job 생성, Worker Lease, Retry, 오류 상태관리 |
| 로컬 LLM AI 분석 Worker | AI 분석 처리 | STT, 회의내용 분석, 분석 JSON 생성, Schema 검증 |
| PMS 반영 모듈 | 실행정보 전환 | Action Item, Risk, Decision 후보를 PMS 데이터로 전환 |
| 감사로그 모듈 | 추적성 관리 | 로그인, 수정, 승인, 배포, PMS 반영 이력 기록 |

## Data Ownership Rules

역할 경계의 기준은 물리 서버가 아니라 데이터 소유권이다. 각 모듈은 자기 소유 데이터에 대한 생성, 변경, 상태 전이 책임을 갖고, 다른 모듈의 업무 판단을 침범하지 않는다.

| 모듈 | 소유 데이터 | 하면 안 되는 일 |
|---|---|---|
| 인증·사용자 모듈 | `users`, `tokens`, `password_reset_tokens` | 음성파일 처리, 분석 Job 처리 |
| 프로젝트 관리 모듈 | `projects`, `project_members`, `project_glossaries` | 파일 저장, STT 처리 |
| 회의 관리 모듈 | `meetings`, `meeting_recording_refs`, `status` | 음성 바이너리 직접 처리 |
| 수집·업로드 모듈 | `ingestion_sessions`, `audio_assets` | 회의록 승인, 이메일 배포 |
| 분석작업 관리 모듈 | `analysis_jobs`, `analysis_job_attempts`, `analysis_workers` | 분석결과 의미 판단 |
| 로컬 LLM AI 분석 Worker | `transcript`, `summary`, `analysis_json` 후보 | 사용자·권한·승인 처리 |
| 회의록 관리 모듈 | `minutes_versions`, `minutes_decisions`, `minutes_action_items` | 음성파일 검증 |
| PMS 반영 모듈 | `tasks`, `risks`, `project_decisions`, `resource_demands` | AI 결과 자동 확정 |
| 배포 모듈 | `distributions`, `delivery_attempts` | 미승인 회의록 발송 |
| 감사로그 모듈 | `audit_logs` | 업무 로직 판단 |

## Workflow Boundary Rules

1. 회의 관리 모듈이 `meeting_id`를 만들고, 수집·업로드 모듈이 `ingestion_session_id`를 만들어 서로 연결한다.
2. 수집·업로드 모듈은 파일이 정상인지와 분석 Job을 만들 수 있는지만 판단한다. 회의록 내용, Action Item, Risk의 업무적 타당성은 판단하지 않는다.
3. 로컬 LLM AI 분석 Worker는 결과 후보를 생성하지만 최종 저장, 버전관리, 승인 상태 변경은 Backend의 플랫폼 데이터/회의록 관리 모듈이 담당한다.
4. 업로드 상태, 분석 상태, 검토 상태, 승인 상태, 배포 상태는 회의 관리 또는 통합 상태조회 경로에서 단일 기준으로 조회한다.
5. AI 결과는 승인 전까지 후보이며, PMS 반영 모듈은 승인된 후보만 실행정보로 전환한다.

## API Boundary

| API Area | Keep? | Rule |
|---|---|---|
| App -> Backend API | Yes | 프로젝트 조회, 업로드 요청, 상태 조회 |
| Web -> Backend API | Yes | 회의록 조회, 수정, 승인, 배포 |
| Backend internal module API | Reduce | 내부 함수 호출, service class, event/job table 사용 |
| Backend -> Analysis Worker | Yes, async | STT/LLM은 오래 걸리므로 Job 방식 |
| Analysis Worker -> Backend | Yes, controlled | 결과 저장 또는 Job 완료 처리 |

## Requirement ID Policy

2026-06-30 요구사항 정의서부터 외부 공유용 공식 기능 요구사항 ID는 `REQ-*` 체계를 사용한다. 수집·업로드 책임은 `REQ-UPL-*`, 분석작업 운영 책임은 `REQ-JOB-*`로 표현한다.

기존 상세 추적용 `COL-*` ID는 유지하되, `COL`은 독립 Collection API 서버를 의미하지 않고 `AI-PMS Backend` 내부의 수집·업로드/분석작업 관리 모듈 요구사항을 의미한다. 예를 들어 `REQ-UPL-001`은 `COL-001`부터 `COL-004`, `REQ-JOB-001`은 `COL-006`부터 `COL-009`와 연결된다.

같은 방식으로 기존 `Platform API` 표현은 외부 API 서버명을 의미하기보다 Backend 내부의 플랫폼 데이터 관리 기능군을 의미하도록 해석한다. 외부 공유 문서에서는 `REQ-AUTH-*`, `REQ-PRJ-*`, `REQ-MTG-*`, `REQ-MIN-*`, `REQ-PMS-*`, `REQ-AUDIT-*`를 우선 사용한다.

## Migration Strategy

1. MVP 문서 기준은 단일 `AI-PMS Backend`와 내부 모듈 구조로 고정한다.
2. 현재 코드에 남아 있는 `backend/`, `collection_api/`, `analysis_server/` 물리 분리는 PoC 구현 흔적으로 본다.
3. 우선 보안 차단 이슈를 해결한 뒤, 수집·업로드와 분석 job 로직을 Backend 내부 모듈로 통합하는 리팩터링을 계획한다.
4. 이후 트래픽, 운영, 배포 독립성, 장애 격리 필요가 생기면 모듈을 독립 서버로 분리할 수 있게 인터페이스를 유지한다.

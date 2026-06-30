# Requirements Traceability And Gap Review

Last updated: 2026-06-30

## Purpose

이 문서는 첨부된 `AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서` v0.1, 2026-06-30을 기준으로 현재 `ai_pms_bootstrap` 구현 상태를 추적한다.

판정 기준:

| Status | Meaning |
|---|---|
| Done | 요구사항을 만족하는 구현과 검증 경로가 있음 |
| Partial | 주요 골격은 있으나 권한, 상태, 검증, 화면, 테스트 중 일부가 부족함 |
| Gap | 요구사항 대비 구현이 없거나 확인되지 않음 |
| Blocker | 보안, 권한, 데이터 무결성상 MVP 수용 전 반드시 수정 필요 |
| Deferred | 요구사항정의서상 후속 확장 또는 낮은 우선순위 |

## Executive Summary

현재 구현은 `AI-PMS Backend`, 수집·업로드/분석작업 관리 기능, `Analysis Worker`, `React Web`, `Android`의 MVP 골격을 갖췄다. 현재 코드에는 PoC 흔적으로 `backend/`, `collection_api/`, `analysis_server/` 물리 폴더가 남아 있지만, 요구사항 기준 구조는 단일 Backend 내부 모듈 + 비동기 Worker다.

MVP 수용 전 차단 항목은 다음이다.

| Priority | Requirement Area | Gap |
|---|---|---|
| P0 | REQ-UPL/REQ-JOB/NREQ-SEC-002 | 수집·업로드/분석 job 엔드포인트가 Backend 인증·권한 경계 없이 열려 있음 |
| P0 | REQ-MIN/REQ-PMS/NREQ-CTRL-001 | 승인 API가 프로젝트 승인 권한을 충분히 검증하지 않고 actor를 요청값으로 받을 수 있음 |
| P0 | REQ-AUTH/NREQ-SEC-003 | 비밀번호 변경/재설정 흐름이 운영 보안 기준에 미달함 |
| P1 | REQ-PRJ/REQ-MTG/NREQ-SEC-002 | 권한 있는 프로젝트만 조회/수정해야 하는 요구사항이 전역적으로 보장되지 않음 |
| P1 | REQ-AI/REQ-MIN | 회의록 버전관리, 승인 요청, 반려 플로우가 요구사항 수준까지 닫히지 않음 |
| P1 | REQ-AUDIT | 감사로그 기록은 일부 있으나 조회, 로그인/로그아웃/권한 변경 전 범위 추적이 부족함 |

## MVP Flow Trace

| Step | Requirement | Current Implementation | Status | Next Action |
|---|---|---|---|---|
| 1 | 사번 기반 로그인 | `/users/login`, token 발급, `/users/me`, logout 있음 | Partial | 로그인 실패 카운트, 비활성/잠금 정책, 감사로그 보강 |
| 2 | 프로젝트 선택 | Android 프로젝트 화면, `/projects` 조회 있음 | Partial | 사용자 권한 프로젝트만 반환하도록 스코프 적용 |
| 3 | 회의 음성 업로드 | Android 녹음/업로드, 수집·업로드 multipart 구현 있음 | Partial | Backend 인증·권한 경계 적용 |
| 4 | 업로드 세션/파일 검증 | size/checksum 검증, upload token 있음 | Partial | content type/format/최대 용량 정책 명시와 테스트 추가 |
| 5 | 분석 job/Worker lease | job claim, lease, heartbeat, retry 있음 | Done | worker 인증 추가 검토 |
| 6 | STT/LLM 분석 | Analysis server/worker, Whisper/Ollama 경로 있음 | Partial | 실기기 end-to-end 검증과 오류 복구 기준 고정 |
| 7 | JSON Schema 검증 | `contracts/analysis_result.schema.json`, validation script 있음 | Partial | Backend 저장 직전 runtime schema enforcement 확인/보강 |
| 8 | 분석결과/회의록 초안 저장 | callback 저장, review package 있음 | Partial | minutes_version_id 기반 버전 모델 보강 |
| 9 | Web 검토/수정/승인 | review edits, approval 있음 | Blocker | 승인 권한/actor 신뢰성 보강, reject/request flow 추가 |
| 10 | 이메일 배포 | preview, distribute, delivery attempts, retry 있음 | Partial | 승인본만 배포하는 guard 회귀 테스트 추가 |
| 11 | PMS 실행정보 반영 | approval 시 task/decision/risk/resource/knowledge 생성 | Partial | 선택 반영 정책과 후보별 reject UI/API 정리 |
| 12 | 감사로그 | 여러 mutation에 insert 있음 | Partial | 로그인/로그아웃/권한/조회 API/검색/내보내기 보강 |

## Official Requirement Snapshot

| Official ID | Status | Current Evidence | Gap |
|---|---|---|---|
| REQ-AUTH-001 | Partial | `/users/login`, token 발급 | 실패 횟수, 잠금 정책, 로그인 감사로그 부족 |
| REQ-AUTH-002 | Partial | 관리자 사용자 등록, role, project member 구조 | 프로젝트 역할 변경 전용 API/권한 검증 부족 |
| REQ-PRJ-001 | Partial | project CRUD 일부 구현 | 권한 프로젝트만 조회 보장과 soft-delete 필요 |
| REQ-PRJ-002 | Partial | project member add/list/delete | 역할 변경 PATCH와 감사로그 필요 |
| REQ-MTG-001 | Partial | meeting create/list/detail/status | 수정/비활성 API와 상태 전이 테스트 필요 |
| REQ-UPL-001 | Blocker | Android upload, upload session, audio asset metadata | Backend 인증·프로젝트 권한 경계 필요 |
| REQ-UPL-002 | Partial | size/checksum 검증 | format/codec/duration/max-size 정책과 테스트 필요 |
| REQ-JOB-001 | Blocker | job claim, lease, heartbeat, retry | job 생성/list/detail/worker endpoint 인증 경계 필요 |
| REQ-AI-001 | Partial | Worker STT/LLM 경로, analysis result 생성 | 실데이터 end-to-end와 품질 경고 검증 필요 |
| REQ-AI-002 | Partial | JSON Schema, validation script | Backend 저장 직전 runtime enforcement 확인 필요 |
| REQ-MIN-001 | Partial | review package, edit endpoint | `minutes_version_id` 기반 버전 모델 보강 |
| REQ-MIN-002 | Blocker | approval endpoint | 승인 권한/actor 신뢰성 보강, reject/request flow 추가 |
| REQ-MIN-003 | Partial | preview/distribute/delivery attempts | 승인본 guard 회귀 테스트와 외부 이메일 정책 필요 |
| REQ-PMS-001 | Partial | approval 시 task/risk 등 생성 | 후보 선택/부분 반영 UX와 권한 검증 필요 |
| REQ-AUDIT-001 | Partial | 여러 mutation insert | 로그인/로그아웃/권한 변경/조회 API/검색/내보내기 보강 |

## Functional Requirement Trace

### 4.1 Auth And User Management

| ID | Status | Evidence | Gap |
|---|---|---|---|
| AUTH-001 | Partial | `backend/app/routers/users.py` `/users/login` | 실패 횟수, 잠금 정책, 로그인 감사로그 부족 |
| AUTH-002 | Partial | `/users/logout` token revoke | 로그아웃 감사로그 확인 필요 |
| AUTH-003 | Done | `backend/app/routers/admin_users.py` `/admin/users` | 공개 회원가입 route는 비활성 |
| AUTH-004 | Partial | user role, admin guard 있음 | 역할별 API 권한 매트릭스가 일관되지 않음 |
| AUTH-005 | Partial | project_members `project_role`, add/list/delete | 프로젝트 역할 변경 전용 API/권한 검증 부족 |
| AUTH-006 | Partial | user status `disabled/locked` | 비밀번호 변경 API가 계정 상태를 우회할 수 있음 |
| AUTH-007 | Deferred | 없음 | 후속 확장 |

### 4.2 Project Management

| ID | Status | Evidence | Gap |
|---|---|---|---|
| PROJ-001 | Done | `POST /projects` | 프로젝트 기간 필드는 없음 |
| PROJ-002 | Partial | `GET /projects`, detail | 권한 프로젝트만 조회 보장 필요 |
| PROJ-003 | Done | `PUT /projects/{project_id}` | 권한 검증 보강 필요 |
| PROJ-004 | Gap | project delete/inactivate route 없음 | soft-delete/status API 필요 |
| PROJ-005 | Gap | 즐겨찾기 없음 | user-project favorite 테이블/API 필요 |
| PROJ-006 | Done | `POST /projects/{project_id}/members` | 권한 검증 보강 필요 |
| PROJ-007 | Done | `GET /projects/{project_id}/members` | 권한 검증 보강 필요 |
| PROJ-008 | Partial | `DELETE /projects/{project_id}/members/{user_id}` | 감사로그/권한 검증 보강 필요 |
| PROJ-009 | Partial | member upsert로 역할 변경 가능 | 명시적 PATCH와 감사로그 필요 |
| PROJ-010 | Deferred | 없음 | 후속 확장 |
| PROJ-011 | Gap | 없음 | 분석 문맥용 glossary API 후보 |

### 4.3 Meeting Management

| ID | Status | Evidence | Gap |
|---|---|---|---|
| MEET-001 | Done | `POST /meetings` |
| MEET-002 | Done | `GET /meetings`, `GET /meetings/{meeting_id}` |
| MEET-003 | Gap | 회의 정보 수정 route 없음 | title/date/type/distribution policy 수정 필요 |
| MEET-004 | Gap | 회의 삭제/비활성 route 없음 | soft-delete/status 필요 |
| MEET-005 | Partial | `GET /meetings/{meeting_id}/status`, Android status screen | 상태 전이 전체 회귀 테스트 필요 |
| MEET-006 | Deferred | attendee API는 있으나 MVP 필수 제외 | 실제 참석자 보정은 후속/선택 |

### 4.4 Collection / Upload Module

공식 요구사항 ID는 `REQ-UPL-*`과 `REQ-JOB-*`를 사용한다. 기존 `COL-*`은 독립 Collection API 서버가 아니라 AI-PMS Backend 내부의 수집·업로드/분석작업 관리 모듈에 대한 상세 추적 ID다.

| ID | Status | Evidence | Gap |
|---|---|---|---|
| COL-001 | Done | Android `PROJECTS` screen |
| COL-002 | Done | Android recorder/upload, multipart upload |
| COL-003 | Blocker | `POST /upload-sessions` | Backend 인증·권한 경계 필요 |
| COL-004 | Done | audio asset metadata/storage |
| COL-005 | Partial | size/checksum 검증 | format/codec/duration/max-size 정책 추가 |
| COL-006 | Blocker | `POST /analysis-jobs` | 인증 없이 job 생성 가능 |
| COL-007 | Done | claim/lease/heartbeat |
| COL-008 | Done | retry_wait/fail/callback retry |
| COL-009 | Done | job detail/status, meeting status |

### 4.5 AI Analysis

| ID | Status | Evidence | Gap |
|---|---|---|---|
| ANA-001 | Done | job completion path, Backend analysis store |
| ANA-002 | Partial | contract schema/script 있음 | 저장 직전 강제 검증 위치 명확화 필요 |
| ANA-003 | Done | review package/minutes draft |
| ANA-004 | Partial | prompts/contracts 중심 | 객관성 회귀 테스트 필요 |
| ANA-005 | Partial | speaker mapping 제외 정책 있음 | LLM 출력 guard/test 필요 |
| ANA-006 | Gap | status는 있으나 minutes version 모델 부족 | STT/AI/user/approved version 분리 필요 |
| ANA-007 | Partial | review_required 상태 있음 | 품질 경고 기준/화면 표시 보강 |

### 4.6 Minutes And Distribution

| ID | Status | Evidence | Gap |
|---|---|---|---|
| MIN-001 | Done | review package |
| MIN-002 | Done | review-edits API |
| MIN-003 | Partial | approved analysis 조회 가능 | 승인본 전용 조회/불변성 보강 |
| MIN-004 | Gap | 없음 | minutes_versions 테이블/API 필요 |
| MIN-005 | Gap | 승인 요청 상태 전환 없음 | draft -> review_required request API 필요 |
| MIN-006 | Blocker | approval API 있음 | approver 권한/actor 신뢰성 보강 |
| MIN-007 | Gap | reject 처리 API 없음 | reject reason 저장 필요 |
| MIN-008 | Partial | project member 기반 자동 수신자 | 외부 수신자 관리는 후속/선택 |
| MIN-009 | Done | distribution preview |
| MIN-010 | Partial | distribute API | 승인본 guard 테스트 필요 |
| MIN-011 | Done | distribution list/attempts |
| MIN-012 | Done | retry API |

### 4.7 PMS Reflection

| ID | Status | Evidence | Gap |
|---|---|---|---|
| PMS-001 | Partial | approval creates tasks | 후보 선택/부분 반영 UX 정리 필요 |
| PMS-002 | Partial | approval creates risks | 후보 선택/부분 반영 UX 정리 필요 |
| PMS-003 | Done | decisions 생성 |
| PMS-004 | Done | resource demands 생성 |
| PMS-005 | Done | project knowledge items |
| PMS-006 | Done | source meeting/analysis ids 저장 |
| PMS-007 | Blocker | approval 기반 반영 | 승인 권한 검증 보강 전까지 차단 |

### 4.8 Documents, 4.9 Notifications

| Area | Status | Gap |
|---|---|---|
| DOC-001~010 | Deferred | 프로젝트 문서관리 후속 확장 |
| NOTI-001~004 | Deferred | 알림 후속 확장 |

### 4.10 Audit

| ID | Status | Evidence | Gap |
|---|---|---|---|
| AUDIT-001 | Partial | 여러 mutation에 `audit_logs` insert | 로그인/로그아웃/비밀번호 변경 누락 |
| AUDIT-002 | Gap | 감사로그 조회 API 없음 | 관리자 조회 필요 |
| AUDIT-003 | Partial | admin user update 일부 기록 | 프로젝트 권한 변경 기록 보강 |
| AUDIT-004 | Partial | project/resource/distribution 일부 기록 | 회의 수정/삭제/버전 기록 필요 |
| AUDIT-005 | Gap | 없음 | 검색 API 필요 |
| AUDIT-006 | Gap | 없음 | CSV/Excel export 후속 |

### 4.11 Task Management

| ID | Status | Evidence | Gap |
|---|---|---|---|
| TASK-001 | Done | review package action item candidates |
| TASK-002 | Partial | approval creates task candidates | 선택 등록 UX/API 보강 |
| TASK-003 | Done | `GET /tasks` |
| TASK-004 | Partial | status update only | title/assignee/due_date edit 필요 |
| TASK-005 | Gap | task delete 없음 |
| TASK-006 | Done | `PATCH /tasks/{task_id}/status` |
| TASK-007 | Gap | 담당자 지정 API 없음 |
| TASK-008 | Gap | 검색 없음 |
| TASK-009 | Partial | project/status 일부 query 확인 필요 |
| TASK-010 | Deferred | 태그 후속 |

### 4.12 Admin

| ID | Status | Evidence | Gap |
|---|---|---|---|
| ADMIN-001 | Partial | dashboard summary | 관리자 전용 운영 화면 고도화 필요 |
| ADMIN-002 | Done | admin user list |
| ADMIN-003 | Partial | analysis health, service health | Backend/DB/Worker 통합 상태 필요 |
| ADMIN-004 | Partial | operations queue | 운영 알림 모델/화면 필요 |

## Nonfunctional Requirement Trace

| ID | Status | Note |
|---|---|---|
| NFR-001 | Done | Android 햄버거 메뉴와 프로젝트/녹음/상태 3단계 흐름으로 단순화 |
| NFR-002 | Done | Worker lease 기반 claim |
| NFR-003 | Done | retry count/error/retry-due 경로 있음 |
| NFR-004 | Partial | 공개 회원가입 없음, 단 password reset/change 운영 보안 보강 필요 |
| NFR-005 | Done | password hash service 사용 |
| NFR-006 | Blocker | 수집·업로드 모듈 인증 및 프로젝트별 접근 제어 보강 필요 |
| NFR-007 | Partial | schema 존재, runtime enforcement 보강 필요 |
| NFR-008 | Partial | audit insert 일부, 조회/전 범위 기록 부족 |
| NFR-009 | Done | Task/Decision/Risk/Resource/Knowledge 확장 구조 있음 |
| NFR-010 | Partial | dashboard/operations queue 일부 |
| NFR-011 | Partial | 정책은 있으나 LLM 회귀 테스트 필요 |
| NFR-012 | Blocker | approval 권한/actor 신뢰성 보강 필요 |

## Recommended Implementation Order

1. 수집·업로드/분석작업 관리 경계 보강: upload session, audio upload, asset register, job create, job list/detail, worker endpoints를 Backend 인증과 worker token으로 보호한다.
2. 승인 권한 보강: `require_active_user`만으로 승인하지 말고 project approver/admin/pm 권한을 확인하고 actor는 token user로 고정한다.
3. 프로젝트 접근 제어: `/projects`, `/meetings`, review package, distribution, tasks/resources/knowledge 조회를 프로젝트 멤버십/역할 기준으로 제한한다.
4. 비밀번호 운영 보안: password change에 현재 사용자 인증/상태 guard를 적용하고, reset token은 dev mode에서만 응답한다.
5. Minutes workflow 완성: approval request, reject reason, immutable approved version, `minutes_versions`를 추가한다.
6. Audit API 완성: 로그인/로그아웃/권한/주요 데이터 변경 기록과 관리자 검색 API를 추가한다.
7. 요구사항 회귀 테스트 추가: 각 요구사항 ID별 smoke script 또는 API-level assertion을 `scripts/verify_mvp_static.sh`에 연결한다.

# AI-PMS 전체 로직 및 파트별 초안 전달안

Last updated: 2026-06-28

## 목적

이 문서는 AI-PMS의 전체 처리 로직을 하나의 기준선으로 묶고, 각 담당 파트에
초안 형태로 전달해 확인받기 위한 작업 문서다.

전달 기준:

- 이 문서는 최종 확정본이 아니라 1차 초안이다.
- 각 담당자는 자기 파트의 API, 데이터, 예외 흐름, 테스트 누락을 확인한다.
- 확인 결과는 "수정 필요", "질문", "승인 가능" 중 하나로 남긴다.
- 전체 제품 범위는 독립 회의록 도구가 아니라 Project_ID 중심 AI-PMS다.

## 기준 문서

- `README.md`
- `docs/08_drive_based_reconfiguration.md`
- `docs/09_kim_heeseop_work_structure.md`
- `docs/15_mvp_first_implementation.md`
- `docs/16_drive_source_inventory.md`
- Drive 원본 `1. 화면설계서/화면별_API_매핑.md`
- Drive 원본 `2. 요구사항정의서/API_계약_초안.md`
- Drive 원본 `4. 협업가이드/협업_운영가이드.md`
- Drive 원본 `5. 프로젝트관리/작업백로그.md`

## 전체 제품 로직

### 1. 사용자와 프로젝트 기준선

Platform API가 사용자, 사번 로그인, 초기 비밀번호 변경, 프로젝트, 프로젝트
멤버, 권한, 감사로그의 기준 시스템이다.

핵심 규칙:

- 모든 업무 데이터는 `Project_ID`에 연결한다.
- 사용자-facing API는 활성 bearer token을 요구한다.
- 관리자 사용자 생성, 비밀번호 초기화, 사용자 상태 변경은 admin 권한에서만
  수행한다.
- LLM 결과는 직접 PMS 상태를 바꾸지 않고 draft/candidate로만 저장한다.

### 2. Android 회의 수집

Android 앱은 회의 현장에서 프로젝트만 선택하고 음성을 녹음한 뒤
Collection API로 업로드한다.

흐름:

1. 사번 로그인
2. 프로젝트 선택
3. 프로젝트 구성원 자동 배포 대상 확인
4. 녹음 시작, 정지, 파일 생성
5. Collection upload session 생성
6. multipart audio upload
7. analysis job 생성
8. job 상태 polling 또는 Platform meeting 상태 확인

### 3. Collection API 수집 및 작업 큐

Collection API는 음성 파일과 분석 작업의 기술적 수집 계층이다. PMS 업무 상태의
최종 판단은 Platform API가 담당한다.

흐름:

1. upload session 발급
2. upload token 검증
3. audio asset 저장 및 metadata 기록
4. analysis job 생성
5. worker heartbeat 수신
6. worker claim/lease/retry 관리
7. job start/complete/fail 기록
8. 완료 시 signed callback을 Platform API로 전송
9. callback 실패 시 backoff와 replay 처리

### 4. Mac mini Analysis Worker

Mac mini는 로컬 분석 서버다. STT, 회의내용 중심 transcript 구조화,
Ollama LLM 분석, JSON schema 검증을 수행한다.

흐름:

1. Collection API에서 job claim
2. audio asset 다운로드 또는 transcript job 수신
3. Whisper.cpp STT
4. 프로젝트 문맥 snapshot 기반 LLM 분석
5. `analysis.v1` JSON 생성
6. JSON schema validation
7. Collection API에 complete/fail 제출

중요 경계:

- Mac mini 결과는 초안이다.
- 승인, 배포, task 생성, risk 생성, resource 생성은 Platform API의 검증과 사람
  승인 이후에만 수행한다.

### 5. Platform API 검토, 승인, PMS 반영

Platform API는 업무 기준 시스템이다. Collection callback 또는 polling 결과를
받아 회의 분석 초안, 회의록 초안, 검토 패키지, 승인 결과를 관리한다.

흐름:

1. meeting 생성 및 Project_ID 연결
2. 프로젝트 문맥 snapshot 저장
3. analysis result 수신 및 schema 검증
4. review package 제공
5. Web에서 transcript, summary, decisions, action_items, risks, resources 검토
6. 승인 전 assignee, due date, priority, 제외 여부 수정
7. 승인 시 PMS task candidate, decision record, risk candidate, resource demand,
   project knowledge item 생성
8. 승인된 회의록만 distribution 가능
9. email delivery, ERP handoff, retry, operations queue 상태 관리

### 6. React Web 시각화 및 운영 콘솔

React Web은 검토, 승인, 운영 확인, 리스크 전환, 배포 재시도, 지식 탐색의 주
사용 화면이다.

주요 화면:

- 로그인, 초기 비밀번호 변경, 비밀번호 재설정
- 관리자 사용자 관리
- 프로젝트 선택
- 최근 회의 처리 상태
- 회의록 검토와 승인
- 이메일 배포 preview/send
- dashboard summary와 attention KPI
- resource usage/cost feedback
- resource conflict, unassigned demand, usage overrun risk promotion
- project knowledge explorer
- operations queue recovery

### 7. PMS 확장 폐쇄 루프

승인된 회의 결과는 PMS 실행 데이터로 연결된다.

연결 규칙:

- action item -> task candidate
- decision -> decision record
- risk -> risk candidate
- required resource -> resource demand
- resource demand -> assignment/reservation
- actual usage -> cost candidate
- cost candidate -> finance/PM approval
- approved cost -> ERP handoff queue
- overdue task, cost overrun, resource conflict, unassigned demand,
  usage overrun -> risk candidate
- approved meeting output -> project knowledge item

## 파트별 전달 초안

### 김강현: Collection API 확인 요청

담당 범위:

- upload session
- upload token
- audio asset 저장
- analysis job
- worker heartbeat
- claim/lease/retry
- Platform callback
- callback replay
- Collection DB migration

확인할 항목:

| 구분 | 확인 내용 |
|---|---|
| API 계약 | Android와 Worker가 호출하는 endpoint, request, response가 구현과 일치하는가 |
| 파일 검증 | 파일 크기, 확장자, content type, checksum, 저장 경로 정책이 충분한가 |
| token | upload token 만료, hash 저장, 재사용 방지 기준이 명확한가 |
| job 상태 | queued, claimed, running, completed, failed, retry_wait 전이가 맞는가 |
| lease | worker 중단 시 lease 만료와 재청구가 안전한가 |
| callback | Platform callback 서명, key id, retry, replay 기준이 충분한가 |
| 테스트 | upload, job claim, complete, fail, callback retry smoke가 있는가 |

전달 문구 초안:

```text
김강현님, Collection API 파트 1차 초안 확인 부탁드립니다.

범위는 upload session, audio asset, analysis job, worker claim/lease/retry,
Platform callback입니다. 현재 AI-PMS 전체 흐름에서는 Collection API가 PMS 업무
판단을 하지 않고, 수집/작업큐/콜백 계층으로만 동작하는 것으로 정리했습니다.

확인 부탁드릴 부분은 다음입니다.
1. Android 업로드와 Worker claim에 필요한 request/response 누락 여부
2. upload token, file validation, checksum, 저장 경로 정책의 보완 필요 여부
3. lease 만료, retry_wait, fail 처리의 상태 전이 오류 여부
4. Platform callback signing, replay, backoff 기준의 보완 필요 여부
5. 현재 smoke test로 부족한 실패 케이스

확인 결과는 "승인 가능", "수정 필요", "질문"으로 남겨주세요.
```

### 박주연: Platform API 확인 요청

담당 범위:

- auth/user/admin
- project core
- meetings
- analysis result storage
- review package
- approval
- task/decision/risk/resource/cost 반영
- email distribution
- ERP handoff queue
- audit log

확인할 항목:

| 구분 | 확인 내용 |
|---|---|
| 권한 | bearer token, admin, pm, finance, resource_manager 권한 경계가 맞는가 |
| Project_ID | 회의, task, decision, risk, resource, cost, knowledge가 모두 Project_ID에 연결되는가 |
| 분석 수신 | Collection callback, schema validation, idempotency가 충분한가 |
| 검토/승인 | 승인 전 수정, 제외, 재승인, 중복 생성 방지가 충분한가 |
| PMS 반영 | task, decision, risk, resource demand, cost candidate 생성 기준이 맞는가 |
| 배포 | 승인 전 배포 차단, email retry, delivery log가 맞는가 |
| 감사 | 상태 변경, 승인, 배포, ERP handoff에 audit log가 남는가 |

전달 문구 초안:

```text
박주연님, Platform API 파트 1차 초안 확인 부탁드립니다.

현재 Platform API는 AI-PMS의 업무 기준 시스템으로 정리했습니다. Collection은
수집과 job 관리, Mac mini는 분석 초안 생성만 담당하고, 최종 검토/승인/PMS
반영/배포/감사는 Platform API에서 통제하는 구조입니다.

확인 부탁드릴 부분은 다음입니다.
1. 사용자, 프로젝트, 회의, 승인, 배포 API 계약 누락 여부
2. Project_ID 기준으로 task, decision, risk, resource, cost, knowledge가 연결되는지
3. Collection callback 수신과 idempotency, schema validation 기준이 충분한지
4. 승인 전/후 상태 전이와 중복 생성 방지 기준이 맞는지
5. email distribution, ERP handoff, operations retry 경계가 적절한지

확인 결과는 "승인 가능", "수정 필요", "질문"으로 남겨주세요.
```

### 김희섭: Android, Web, Mac mini, 통합 확인 항목

담당 범위:

- Android 앱
- React Web
- Mac mini Analysis Worker
- analysis JSON schema
- screen/API mapping
- 통합 상태 전이
- 외부 접속과 APK 제공
- 문서화와 검증

확인할 항목:

| 구분 | 확인 내용 |
|---|---|
| Android | 로그인, 프로젝트 선택, 자동 배포 대상 확인, 녹음, 업로드, 상태 확인 UX가 연결되는가 |
| Web | 로그인, 검토, 승인, 배포, dashboard, resource/risk/operations 시각화가 연결되는가 |
| Analysis | STT, LLM, JSON validation, fail 처리, model metadata가 충분한가 |
| 통합 | Android -> Collection -> Worker -> Platform -> Web 승인 흐름이 끊기지 않는가 |
| 외부 접속 | 임시 tunnel, LAN URL, APK endpoint 기본값이 현 상태와 일치하는가 |
| 문서 | 화면, API, DB, 테스트 trace가 문서에 남아 있는가 |

전달 문구 초안:

```text
김희섭 파트는 Android, Web, Mac mini Analysis, 통합 문서 기준으로 확인합니다.

현재 외부 Web, Platform API, Collection API, Analysis Server는 cloudflared 임시
터널로 열려 있고, Android public debug APK에는 외부 Platform/Collection URL을
기본값으로 주입했습니다.

추가 확인할 부분은 다음입니다.
1. Android 실기기에서 로그인, 녹음, 업로드, job 생성, 상태 확인까지 실제 동작 여부
2. Web에서 회의 검토, 승인, 배포, operations recovery, risk promotion UX 확인
3. Mac mini Worker가 실제 audio job을 claim하고 STT/LLM 완료까지 수행하는지
4. 클로버노트/다글로 UI 벤치마킹 방향과 이노그리드 톤앤매너 반영 수준
5. 임시 터널을 고정 도메인 Cloudflare Tunnel로 전환할 필요 여부
```

## 전체 리뷰 체크리스트

| 단계 | 담당 | 1차 상태 | 확인 필요 |
|---|---|---|---|
| 사용자/권한 | Platform | 구현 초안 있음 | 권한 matrix와 감사로그 보완 확인 |
| 프로젝트 코어 | Platform | 구현 초안 있음 | 일정/WBS 심화 모델 확인 |
| Android 수집 | 김희섭 | APK 산출 완료 | 실기기 E2E 확인 |
| Collection 수집 | 김강현 | 구현 초안 있음 | 파일 검증, lease, retry 확인 |
| Mac mini 분석 | 김희섭 | 구현 초안 있음 | 실제 음성 job 반복 검증 |
| Web 검토/승인 | 김희섭 | 구현 초안 있음 | UI/UX 벤치마킹 반영 확인 |
| PMS 반영 | Platform | 구현 초안 있음 | task/resource/cost/risk 정책 확인 |
| 배포/ERP | Platform | 구현 초안 있음 | 실제 SMTP/ERP credential 필요 |
| 외부 접속 | 김희섭 | 임시 터널 완료 | 고정 도메인 전환 필요 |
| APK 제공 | 김희섭 | public debug APK 완료 | release signing 필요 |

## 현재 공유 가능한 실행 정보

임시 외부 접속:

- 실행 허브: `https://textiles-zen-syndrome-ultimately.trycloudflare.com/run/`
- Web: `https://textiles-zen-syndrome-ultimately.trycloudflare.com`
- APK 다운로드: `https://textiles-zen-syndrome-ultimately.trycloudflare.com/downloads/`
- APK 설치 확인: `https://textiles-zen-syndrome-ultimately.trycloudflare.com/downloads/install.html`
- 파트별 확인 초안: `https://textiles-zen-syndrome-ultimately.trycloudflare.com/handoff/`
- 검토 패키지 JSON: `https://textiles-zen-syndrome-ultimately.trycloudflare.com/handoff/public-review-package.json`
- 검토 회신 템플릿: `https://textiles-zen-syndrome-ultimately.trycloudflare.com/handoff/review-response-template.md`
- Platform API: `https://other-musicians-recorded-different.trycloudflare.com/docs`
- Collection API: `https://warrior-copyright-opinion-saturn.trycloudflare.com/docs`
- Analysis Server: `https://monday-cables-optional-cancer.trycloudflare.com/docs`

APK:

- `artifacts/apk/AI-PMS-Recorder.apk`
- `artifacts/apk/AiPmsAndroidClient-public-debug.apk`
- `artifacts/apk/AiPmsAndroidClient-responsive-public-debug.apk`
- 앱 ID: `com.aipms`
- 앱명: `AI-PMS Recorder`
- 외부 테스트 담당자에게는 `AI-PMS-Recorder.apk`를 우선 전달하고, 긴 파일명은
  빌드 추적용으로 유지한다.
- 하나의 APK가 phone-width 화면은 single-column, tablet-width 화면은 two-column
  layout으로 자동 전환한다.
- Web 콘솔 상단의 `APK 다운로드` 링크에서도 같은 다운로드 페이지로 이동한다.
- Web 콘솔 상단의 `실행 허브` 링크에서 Web/API/APK 실행 경로를 함께 확인한다.
- Web 콘솔 상단의 `파트 전달안` 링크에서 담당자별 확인 초안과 외부 URL을
  함께 확인할 수 있다.
- React public routes는 `/run/execution.json`을 우선 읽어 현재 터널 URL과 APK
  metadata를 표시하고, manifest가 없을 때만 fallback URL을 사용한다.
- USB 연결 기기 설치 검증은 `scripts/install_android_public_debug_apk.sh`로
  수행하고 결과는 `runtime/android_public_install/latest_install_check.json`에
  남긴다. 같은 결과는 사람이 바로 읽을 수 있도록
  `runtime/android_public_install/latest_install_check.md`와
  `../배포_APK/설치검증_리포트.md`에도 기록한다.
- 회신 템플릿을 채운 파일은 `runtime/review_responses/inbox/`에 모으고
  `scripts/collect_public_review_responses.sh`로 요약한다.
- 기본 Platform API: `https://other-musicians-recorded-different.trycloudflare.com`
- 기본 Collection API: `https://warrior-copyright-opinion-saturn.trycloudflare.com`
- 장기 외부 배포 전 release signing 준비 상태는
  `../배포_APK/릴리즈서명_준비상태.md`와
  `bash scripts/smoke_android_release_readiness.sh`로 확인한다.

주의:

- 위 URL은 임시 tunnel이다. Mac mini나 tunnel 세션이 재시작되면 바뀔 수 있다.
- 임시 tunnel과 public APK는 `scripts/run_public_tunnels.sh` 이후
  `scripts/refresh_public_handoff_bundle.sh`로 APK publish, review package
  생성, public smoke를 한 번에 재실행한다.
- APK까지 현재 tunnel URL로 재빌드해야 하면
  `AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh`를
  사용한다.
- `scripts/smoke_public_access.sh`는 외부 공유 전 public download and handoff
  routes, execution hub, install guide, review package JSON, review response
  template, APK metadata/file, API health, Platform CORS를 함께 검증한다.
- 팀 검토용으로는 충분하지만 운영/시연 고정 URL은 Cloudflare named tunnel 또는
  별도 배포 도메인으로 전환해야 한다.
- 고정 URL 전환 준비는 `scripts/prepare_cloudflare_named_tunnel.sh`,
  `scripts/run_cloudflare_named_tunnel.sh`,
  `docs/19_cloudflare_named_tunnel_plan.md` 기준으로 진행한다.
- APK는 현재 debug signing이다. 외부 배포나 장기 설치용 release APK 준비는
  `scripts/prepare_android_release_signing.sh`,
  `scripts/build_android_release_apk.sh`,
  `docs/20_android_release_signing.md` 기준으로 진행한다.

## 확인 요청 방식

각 담당자에게 이 문서를 먼저 공유하고 다음 형식으로 회신을 요청한다.

```text
담당 파트:
결론: 승인 가능 / 수정 필요 / 질문
수정 필요 항목:
질문:
추가 테스트 필요 항목:
```

## 다음 실행 순서

1. 각 담당자에게 위 초안 전달
2. Collection API 확인 결과 반영
3. Platform API 확인 결과 반영
4. Android 실기기 APK 설치 및 E2E 테스트
5. Web 검토/승인/배포 UX 점검
6. 고정 외부 접속 도메인 전환
7. release APK signing 준비
8. 전체 static/smoke verification 재실행

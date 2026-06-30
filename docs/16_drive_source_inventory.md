# Drive Source Inventory

Last updated: 2026-06-30

## Source Root

```text
/Users/ppp/Library/CloudStorage/GoogleDrive-heen1987@gmail.com/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1
```

This is the authoritative planning and design folder for the AI-PMS project.
The parent `새싹교육_프로젝트` folder is only a container.

## Priority Documents For Development

- `README.md`: project purpose, current deliverables, and work principles
- `2. 요구사항정의서/요구사항정의서.md`: MVP functional and non-functional requirements
- `2. 요구사항정의서/AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx`:
  formal submission requirements definition
- `2. 요구사항정의서/AI_PMS_MVP_요구사항정의서.md`: Markdown source for the
  formal MVP requirements definition
- `2. 요구사항정의서/AI_PMS_확장요구사항.md`: Project_ID-centered PMS expansion scope
- `개요/AI_PMS_ERD_구조.md`: integrated Project_ID-centered ERD and migration boundary
- `개요/diagrams/19_ai_pms_integrated_erd.mmd`: Mermaid source for the integrated ERD
- `2. 요구사항정의서/Platform_API_상세요구사항.md`: Platform API ownership
- `2. 요구사항정의서/Collection_API_상세요구사항.md`: Collection API ownership
- `2. 요구사항정의서/인증_사용자관리_정책.md`: employee-number auth and account policy
- `1. 화면설계서/화면설계서.md`: Android and React Web screens
- `1. 화면설계서/화면별_API_매핑.md`: screen-to-API traceability
- `5. 프로젝트관리/작업백로그.md`: backlog and priority tracking
- `5. 프로젝트관리/의사결정_기록.md`: decision log
- `3. 포트폴리오 정리/AI_PMS_MVP_실행검증_포트폴리오.md`: MVP execution
  evidence bundle for Web/API/APK handoff review
- `4. 협업가이드/협업_운영가이드.md`: role boundary and Definition of Done
- `개요/diagrams/*.mmd`: architecture and traceability diagram sources
- `ai_pms_bootstrap/docs/21_erd_structure.md`: local implementation notes for the integrated ERD
- `ai_pms_bootstrap/web_client/public/requirements/AI-PMS-requirements-v0.2.docx`:
  public DOCX mirror for the execution hub and reviewer handoff
- `ai_pms_bootstrap/web_client/public/requirements/AI-PMS-requirements-v0.2.md`:
  public Markdown mirror for quick review
- `ai_pms_bootstrap/web_client/public/requirements/requirements.json`: public
  requirements manifest with hashes, sizes, URLs, and MVP scope controls

## Confirmed Role Boundary

The Drive collaboration guide assigns:

- 김강현: Collection API
- 박주연: Platform API
- 김희섭: Android, React Web, Mac mini Analysis, integration design, JSON validation, documentation

For this local scaffold, implementation may cross service boundaries to keep
the MVP runnable, but documents and final handoff should preserve this service
ownership boundary.

## Automation Rule

The hourly development loop should check this Drive root before selecting the
next implementation slice, then reconcile it with local scaffold documents:

- `docs/09_kim_heeseop_work_structure.md`
- `docs/15_mvp_first_implementation.md`
- `docs/08_drive_based_reconfiguration.md`

## Current Screen/API Reconciliation

- `1. 화면설계서/` contains the current Web/App image reference set used for the
  MEETFLOW workspace UI pass.
- `web_client/src/main.tsx` and `web_client/src/styles.css` now reflect the
  screen-design direction: PMS workspace sidebar, KPI strip, task board,
  document area, meeting review panel, and Android phone preview.
- The tester-facing install package is available as a direct APK handoff at
  `배포_APK/AI-PMS-Recorder.apk` under this Drive source root.
- `배포_APK/README.md`, `배포_APK/AI-PMS-Recorder.sha256`, and
  `배포_APK/apk_manifest.json` provide installation and checksum validation
  without changing the APK into a zip package.
- `배포_APK/설치검증_리포트.md` records the latest dry-run or physical-device APK
  install check, including the no-manual-attendee-selection guard.
- `배포_APK/릴리즈서명_준비상태.md` records the release-signing readiness state
  before replacing debug-signed APK handoff with a release APK.
- `3. 포트폴리오 정리/AI_PMS_MVP_실행검증_포트폴리오.md` records the current
  execution evidence, direct APK hash, public URLs, verification commands, and
  external gaps for portfolio review.
- `ai_pms_bootstrap/web_client/public/run/index.html` and
  `ai_pms_bootstrap/web_client/public/handoff/index.html` now expose the
  formal requirements DOCX alongside the APK and review package.
- `scripts/publish_requirements_documents.sh` and
  `scripts/smoke_requirements_publication.sh` keep the public requirements
  mirror aligned with the Drive DOCX/Markdown source.
- `scripts/smoke_public_access.sh` can now verify explicit Web, Platform,
  Collection, and Analysis URLs before falling back to environment variables or
  quick-tunnel logs, which prevents stale log URLs from being mistaken for the
  active external access contract.
- `scripts/doctor_public_handoff.sh` records non-mutating public handoff
  readiness diagnostics in `runtime/public_handoff/latest_doctor.json` and
  `runtime/public_handoff/latest_doctor.md` before external links are shared.

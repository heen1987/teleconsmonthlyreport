# Project Scope

## Positioning

이 프로젝트의 메인 범위는 AI-PMS입니다. 회의 음성녹음 수집, 분석, 회의록
검토/승인, 이메일 배포는 PMS 전체 기능 중 첫 번째 AI 자동화 모듈입니다.
독립 회의록 플랫폼으로 정의하지 않습니다.

```text
AI-PMS
├─ Project Core
│  ├─ project_id, contract, WBS, budget
│  ├─ members, roles, permissions
│  └─ audit logs
├─ Execution Management
│  ├─ schedule and milestones
│  ├─ tasks and issues
│  ├─ decisions
│  └─ documents and knowledge
├─ Resource Management
│  ├─ resource demand
│  ├─ assignment/reservation
│  ├─ time sheet/usage
│  └─ cost/risk feedback
├─ Notification And Distribution
└─ AI Modules
   └─ Meeting intelligence module (first MVP module)
      ├─ Android audio recording/upload
      ├─ Collection API upload/session/job lease
      ├─ Mac mini STT and local LLM analysis
      ├─ meeting minutes draft
      ├─ decision/action item/risk/resource extraction
      ├─ Web review and approval
      ├─ PMS task candidate creation
      └─ approved minutes distribution
```

## One-Line Description

프로젝트, 일정, 자원, 업무, 위험, 지식, 승인, 감사 이력을 `Project_ID`
중심으로 관리하는 AI-PMS를 구축하고, 첫 번째 모듈로 회의 음성 수집,
STT, 로컬 LLM 분석, 회의록 승인/배포, Task 반영 기능을 제공한다.

## Included In MVP

- project_id 기반 프로젝트 선택
- 사용자, 사번 로그인, 초기 비밀번호 변경, 계정 상태
- 프로젝트 구성원 자동 배포 대상 확인
- Android 회의 녹음 및 업로드
- Collection API 업로드 세션, 파일 검증, 분석 job/lease
- Mac mini Worker STT, 발언자 임의 추정 없는 회의내용 구조화,
  로컬 LLM JSON 분석
- Platform API 분석 결과 저장, 회의록 초안, 검토/수정/승인
- 승인된 Action Item의 PMS Task 후보 생성
- 결정사항, 위험, 필요 자원 후보 저장
- 이메일 배포 이력
- 상태 추적과 감사 로그

## Excluded From MVP

- 참석자 선택 필수화
- 화자 매핑 또는 발언자/담당자 임의 추정
- 실시간 자막
- 공개 회원가입
- AI 결과 자동 확정
- ERP 실시간 연동
- 문서관리, 알림, 고도화된 업무보드, 사용자 그룹관리, 관리자 대시보드,
  자원관리, 비용관리의 전체 기능
- full ERP/accounting automation
- automatic ERP/HCM ledger replacement
- real-time multi-user STT or live meeting assistant
- automatic tax filing
- automatic payment execution
- automatic accounting journal posting
- external ERP/Jira/Confluence integration
- large-scale OCR/document processing
- 30B+ local model operation

## Expansion Direction

1차 MVP 이후에는 회의에서 추출된 Action Item, Risk, Required Resource를
PMS Core와 연결합니다. 확장 순서는 Task, Schedule, Resource, Risk,
Cost, Knowledge, Dashboard, External ERP/HCM integration 순서로 잡습니다.

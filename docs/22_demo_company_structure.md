# 새싹테크솔루션 가상회사 데모 조직 구조

이 문서는 AI-PMS 시연/개발 DB에 넣을 기준 회사 모델을 정의한다.
원천 데이터는 `saessak_virtual_company_dataset_pms_login_revised.xlsx`에서 추출한
`scripts/data/saessak_company_dataset.json`이다.

회의 녹음 앱은 참석자를 직접 선택하지 않고 프로젝트만 선택하므로, 각 프로젝트의
`project_members`가 회의록 자동 배포 대상의 원천 데이터가 된다.

## 회사 기준

| 항목 | 값 |
| --- | --- |
| 회사명 | 새싹테크솔루션 주식회사 |
| 영문명 | Saessak Tech Solutions Co., Ltd. |
| 업종 | AI·클라우드 기반 B2B 솔루션 개발 |
| 설립일 | 2021-03-15 |
| 본사 | 서울특별시 마포구 디지털로 128 |
| 대표이사 | 김도윤 |
| 회계연도 | 2026 |
| 연매출 | 100억 원 |
| 총 인원 | 50명 |
| 프로젝트 | 15개 |
| 본부 | 3개 |
| 팀 | 11개 |
| 데모 총 연봉 | 약 34.97억 원 |
| 총 투입 | 50.0 M/M |
| 총 투입 인건비 | 4.32억 원 |

## 로그인/계정 기준

| 항목 | 값 |
| --- | --- |
| 계정 수 | 50개 |
| 로그인ID | 사번과 동일 (`E001`~`E050`) |
| 초기비밀번호 | `1234` |
| 로그인 방식 | 사번 로그인 |
| 계정 상태 | 활성 |
| 원본 권한그룹 | `ADMIN` 1명, `MANAGER` 12명, `LEAD` 6명, `MEMBER` 31명 |

PMS 내부 role은 원본 권한그룹을 그대로 저장하지 않고 앱 권한 체계에 맞게 변환한다.
`ADMIN`은 `admin`, `LEAD`는 `pl`, 재무팀은 `finance`, 인사/HR 담당은
`resource_manager`, 나머지 관리자 그룹은 `pm`, 일반 구성원은 `member`로 매핑한다.
원본 권한그룹과 로그인 메모는 사용자 metadata에 함께 보존한다.

## 본부 구성

| 본부 | 인원 | 프로젝트 수 | 구성 |
| --- | ---: | ---: | --- |
| 경영본부 | 10명 | 2개 | CEO실, 인사팀, 기획팀, 재무팀 |
| 연구소 | 15명 | 5개 | AI연구팀, 데이터연구팀, 플랫폼R&D팀 |
| 개발본부 | 25명 | 8개 | 백엔드팀, 프론트엔드팀, 모바일팀, QA/DevOps팀 |

## 조직 구성

| 본부 | 팀 | 현재인원 | 책임자 | 주요업무 |
| --- | --- | ---: | --- | --- |
| 경영본부 | CEO실 | 2명 | 김도윤 | 전사 전략, 경영지원 총괄 |
| 경영본부 | 인사팀 | 2명 | 이민준 | 채용, 평가, 교육, 조직문화 |
| 경영본부 | 기획팀 | 3명 | 정하준 | 사업기획, PMO, 성과관리 |
| 경영본부 | 재무팀 | 3명 | 강유진 | 예산, 회계, 정산, 손익관리 |
| 연구소 | AI연구팀 | 5명 | 문태오 | LLM, NLP, 비전 AI 연구 |
| 연구소 | 데이터연구팀 | 5명 | 권도현 | 데이터 분석, 추천모델, BI |
| 연구소 | 플랫폼R&D팀 | 5명 | 홍서준 | MLOps, 플랫폼 아키텍처, 성능 |
| 개발본부 | 백엔드팀 | 7명 | 유민석 | API, 서버, DB, 배치 개발 |
| 개발본부 | 프론트엔드팀 | 6명 | 오세은 | 웹 UI, 디자인시스템, 관리자 콘솔 |
| 개발본부 | 모바일팀 | 5명 | 윤서진 | iOS, Android, Flutter 앱 개발 |
| 개발본부 | QA/DevOps팀 | 7명 | 홍지아 | 테스트 자동화, CI/CD, 클라우드 운영 |

## 프로젝트 구성

| 담당 본부 | 프로젝트 수 | 배정건수 | 총투입M/M | 매출배분 |
| --- | ---: | ---: | ---: | ---: |
| 경영본부 | 2개 | 39건 | 8.6 | 10억 원 |
| 연구소 | 5개 | 51건 | 12.5 | 32억 원 |
| 개발본부 | 8개 | 117건 | 28.9 | 58억 원 |

프로젝트별 구성원 수는 5명부터 21명까지 다르며, 총 `207`개의 프로젝트 배정이 있다.
각 배정은 Excel의 `투입M/M`을 `planned_mm`로 저장하고, `allocation_percent`는
1.0M 기준 비율(`투입M/M * 100`)로 변환한다. 직원별 총 투입은 모두 `1.0M/M`이며,
최대 단일 프로젝트 투입은 `0.6M/M`이다.

## 생성 스크립트

Excel 원본에서 fixture JSON 재생성:

```powershell
C:\Users\김희섭\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe `
  scripts\import_saessak_company_dataset.py `
  --input "G:\내 드라이브\새싹교육_프로젝트\새싹교육_프로젝트 1\7. 가상회사_새싹테크솔루션\saessak_virtual_company_dataset_pms_login_revised.xlsx" `
  --output scripts\data\saessak_company_dataset.json
```

계획 JSON만 생성:

```bash
backend/.venv/bin/python scripts/seed_demo_company.py
```

Windows 개발본 기준:

```powershell
backend\.venv-win\Scripts\python.exe scripts\seed_demo_company.py
```

DB에 실제 반영:

```bash
backend/.venv/bin/python scripts/seed_demo_company.py --apply
```

생성 결과는 `runtime/demo_company/latest_plan.json`에 저장된다.
DB 반영 시 사용자, 인력 리소스, 프로젝트, 프로젝트 구성원, 연봉 스냅샷,
계획 M/M, 직급별 1M 단가, 배정 원가를 upsert한다.
계정 기본 비밀번호는 `1234`, 기본 상태는 `active`다.

## 자동 배포 기준

회의 앱에서 프로젝트를 선택하면 다음 데이터 흐름을 따른다.

```text
프로젝트 선택
  -> project_members 조회
  -> 프로젝트 구성원 자동 배포 대상 확인
  -> 녹음/업로드
  -> 분석 결과 생성
  -> project_members의 활성 사용자 이메일로 회의록 자동 배포
```

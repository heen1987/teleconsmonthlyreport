# AI-PMS DB exports

이 폴더는 협업자가 로컬 PostgreSQL 개발 DB를 맞출 수 있도록 생성한 SQL 산출물을 보관한다.

## 파일 구분

- `*_schema_only.sql`: 테이블, 인덱스, 제약조건 등 DB 구조만 포함한다.
- `*_collab_demo.sql`: DB 구조와 데모 데이터를 포함하되 `access_tokens`, `password_reset_tokens` 테이블 데이터는 제외하고, 모든 사용자 `password_hash`를 협업용 공통 데모 비밀번호 기준으로 재설정한다.

## 복원 예시

```powershell
docker exec ai_pms_db createdb -U ai_pms ai_pms_collab
docker cp outputs/db_exports/ai_pms_20260630_134609_collab_demo.sql ai_pms_db:/tmp/ai_pms_collab.sql
docker exec ai_pms_db psql -U ai_pms -d ai_pms_collab -v ON_ERROR_STOP=1 -f /tmp/ai_pms_collab.sql
```

## 보안 주의

`*_full_internal.sql`, `*_data_only_internal.sql`, `*_shareable_no_token_tables.sql`, `*_sql_exports.zip` 파일은 내부 검증용 산출물이라 Git 추적 대상에서 제외한다.

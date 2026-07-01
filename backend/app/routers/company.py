from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.schemas import (
    CompanyContextOut,
    CompanyContextSummaryOut,
    CompanyDivisionOut,
    CompanyProfileOut,
    CompanyProfileUpsert,
)
from app.services.auth_tokens import require_active_user, require_admin_user

router = APIRouter(prefix="/company", tags=["company"])


COMPANY_COLUMNS = [
    "company_id",
    "company_name",
    "english_name",
    "industry",
    "founded_on",
    "headquarters",
    "ceo",
    "fiscal_year",
    "annual_revenue_krw",
    "headcount",
    "project_count",
    "organization_summary",
    "headcount_summary",
    "note",
    "source_file",
    "metadata",
    "created_at",
    "updated_at",
]


def _fetch_profile(cursor, company_id: str | None = None) -> dict | None:
    where = "WHERE company_id = %s" if company_id else ""
    params = (company_id,) if company_id else ()
    cursor.execute(
        f"""
        SELECT {", ".join(COMPANY_COLUMNS)}
        FROM company_profiles
        {where}
        ORDER BY created_at ASC
        LIMIT 1
        """,
        params,
    )
    return cursor.fetchone()


def _json_ready(value: Any) -> Any:
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, dict):
        return {key: _json_ready(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_ready(item) for item in value]
    return value


@router.get("/profile", response_model=CompanyProfileOut)
def get_company_profile(_current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            profile = _fetch_profile(cursor)
    if profile is None:
        raise HTTPException(status_code=404, detail="Company profile not found")
    return profile


@router.put("/profile", response_model=CompanyProfileOut)
def upsert_company_profile(
    payload: CompanyProfileUpsert,
    current_user: dict = Depends(require_admin_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            before = _fetch_profile(cursor, payload.company_id)
            cursor.execute(
                """
                INSERT INTO company_profiles
                    (company_id, company_name, english_name, industry, founded_on, headquarters,
                     ceo, fiscal_year, annual_revenue_krw, headcount, project_count,
                     organization_summary, headcount_summary, note, source_file, metadata)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (company_id)
                DO UPDATE SET
                    company_name = EXCLUDED.company_name,
                    english_name = EXCLUDED.english_name,
                    industry = EXCLUDED.industry,
                    founded_on = EXCLUDED.founded_on,
                    headquarters = EXCLUDED.headquarters,
                    ceo = EXCLUDED.ceo,
                    fiscal_year = EXCLUDED.fiscal_year,
                    annual_revenue_krw = EXCLUDED.annual_revenue_krw,
                    headcount = EXCLUDED.headcount,
                    project_count = EXCLUDED.project_count,
                    organization_summary = EXCLUDED.organization_summary,
                    headcount_summary = EXCLUDED.headcount_summary,
                    note = EXCLUDED.note,
                    source_file = EXCLUDED.source_file,
                    metadata = EXCLUDED.metadata,
                    updated_at = now()
                RETURNING company_id, company_name, english_name, industry, founded_on,
                    headquarters, ceo, fiscal_year, annual_revenue_krw, headcount,
                    project_count, organization_summary, headcount_summary, note,
                    source_file, metadata, created_at, updated_at
                """,
                (
                    payload.company_id,
                    payload.company_name,
                    payload.english_name,
                    payload.industry,
                    payload.founded_on,
                    payload.headquarters,
                    payload.ceo,
                    payload.fiscal_year,
                    payload.annual_revenue_krw,
                    payload.headcount,
                    payload.project_count,
                    payload.organization_summary,
                    payload.headcount_summary,
                    payload.note,
                    payload.source_file,
                    Jsonb(payload.metadata),
                ),
            )
            profile = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'company_profile_upsert', 'company_profiles', %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    payload.company_id,
                    Jsonb(_json_ready(dict(before))) if before is not None else None,
                    Jsonb(_json_ready(dict(profile))),
                ),
            )
    return profile


@router.get("/context", response_model=CompanyContextOut)
def get_company_context(_current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            profile = _fetch_profile(cursor)
            cursor.execute(
                """
                SELECT
                    (SELECT count(*) FROM users) AS users,
                    (SELECT count(*) FROM users WHERE status = 'active') AS active_users,
                    (SELECT count(*) FROM projects) AS projects,
                    (SELECT count(*) FROM project_members) AS project_members,
                    (SELECT count(*) FROM resource_profiles WHERE status = 'active') AS resource_profiles,
                    COALESCE((SELECT sum(planned_mm) FROM project_members), 0) AS total_planned_mm,
                    COALESCE((SELECT sum(allocated_cost_krw) FROM project_members), 0) AS total_allocated_cost_krw
                """
            )
            summary = CompanyContextSummaryOut.model_validate(cursor.fetchone())
            cursor.execute(
                """
                SELECT
                    COALESCE(NULLIF(metadata->>'division_name', ''), location, 'Unassigned') AS division_name,
                    count(DISTINCT COALESCE(NULLIF(metadata->>'team_name', ''), 'Unassigned')) AS team_count,
                    count(*) AS user_count
                FROM resource_profiles
                WHERE resource_type = 'human'
                  AND status = 'active'
                GROUP BY 1
                ORDER BY user_count DESC, division_name ASC
                """
            )
            divisions = [CompanyDivisionOut.model_validate(row) for row in cursor.fetchall()]
    return CompanyContextOut(profile=profile, summary=summary, divisions=divisions)

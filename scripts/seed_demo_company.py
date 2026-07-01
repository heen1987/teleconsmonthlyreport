#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "backend"))

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.services.passwords import hash_password


DATASET_PATH = ROOT_DIR / "scripts" / "data" / "saessak_company_dataset.json"
INITIAL_PASSWORD = "1234"
OUTPUT_PATH = ROOT_DIR / "runtime" / "demo_company" / "latest_plan.json"
VALID_USER_ROLES = {"admin", "pm", "pl", "member", "finance", "resource_manager", "viewer"}


def load_dataset(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def revenue_label(annual_revenue_krw: int) -> str:
    if annual_revenue_krw % 100_000_000 == 0:
        return f"{annual_revenue_krw // 100_000_000}억 원"
    return f"{annual_revenue_krw:,}원"


def normalized_project_role(raw_role: str | None) -> str:
    role = (raw_role or "").strip()
    if role == "PM":
        return "pm"
    if "Sponsor" in role:
        return "sponsor"
    if "PL" in role:
        return "pl"
    if "QA" in role:
        return "qa"
    if "DevOps" in role:
        return "devops"
    if "개발" in role:
        return "developer"
    if "관리" in role:
        return "manager"
    if "지원" in role:
        return "support"
    return "member"


def build_users(dataset: dict[str, Any]) -> list[dict[str, Any]]:
    company = dataset["company"]
    users: list[dict[str, Any]] = []
    for employee in dataset["employees"]:
        account_role = employee.get("account_role") or "member"
        if account_role not in VALID_USER_ROLES:
            account_role = "member"
        metadata = {
            "company_id": company["company_id"],
            "company_name": company["company_name"],
            "english_name": company.get("english_name"),
            "annual_revenue_krw": company["annual_revenue_krw"],
            "division_name": employee["division"],
            "team_name": employee["team"],
            "position": employee["position"],
            "duty": employee["duty"],
            "login_id": employee.get("login_id"),
            "auth_group": employee.get("auth_group"),
            "account_status_text": employee.get("account_status"),
            "login_method": employee.get("login_method"),
            "account_note": employee.get("account_note"),
            "employment_type": employee.get("employment_type"),
            "hire_date": employee.get("hire_date"),
            "phone": employee.get("phone"),
            "work_location": employee.get("location"),
            "skill_tags": employee.get("skill_tags", []),
            "primary_project": employee.get("primary_project"),
            "total_allocation_rate": employee.get("total_allocation_rate"),
            "annual_salary_krw": employee["annual_salary_krw"],
            "status_text": employee.get("status_text"),
            "source_file": dataset["source"]["file_name"],
        }
        users.append(
            {
                "user_id": employee["user_id"],
                "employee_no": employee["employee_no"],
                "login_id": employee.get("login_id") or employee["employee_no"],
                "initial_password": str(employee.get("initial_password") or INITIAL_PASSWORD),
                "name": employee["name"],
                "email": employee.get("email"),
                "role": account_role,
                "status": AccountStatus.ACTIVE.value,
                "division_name": employee["division"],
                "team_name": employee["team"],
                "position": employee["position"],
                "duty": employee["duty"],
                "auth_group": employee.get("auth_group"),
                "account_status_text": employee.get("account_status"),
                "login_method": employee.get("login_method"),
                "account_note": employee.get("account_note"),
                "annual_salary_krw": employee["annual_salary_krw"],
                "resource_id": employee["resource_id"],
                "metadata": metadata,
            }
        )
    return users


def build_projects(dataset: dict[str, Any]) -> list[dict[str, Any]]:
    projects: list[dict[str, Any]] = []
    for project in dataset["projects"]:
        tags = ", ".join(project.get("technology_tags") or [])
        description_parts = [
            project.get("description"),
            f"담당조직: {project.get('division')} / {project.get('team')}",
            f"우선순위: {project.get('priority_text')}",
            f"매출배분: {int(project.get('revenue_allocation_krw') or 0):,}원",
        ]
        if tags:
            description_parts.append(f"주요기술: {tags}")
        projects.append(
            {
                "project_id": project["project_id"],
                "name": project["project_name"],
                "status": project.get("status_code") or "active",
                "pm_user_id": project["pm_user_id"],
                "owning_division_name": project.get("division"),
                "owning_team_name": project.get("team"),
                "description": " | ".join(part for part in description_parts if part),
                "metadata": {
                    "status_text": project.get("status_text"),
                    "priority_text": project.get("priority_text"),
                    "priority_code": project.get("priority_code"),
                    "start_date": project.get("start_date"),
                    "end_date": project.get("end_date"),
                    "duration_months": project.get("duration_months"),
                    "registered_employee_count": project.get("registered_employee_count"),
                    "revenue_allocation_krw": project.get("revenue_allocation_krw"),
                    "revenue_share": project.get("revenue_share"),
                    "total_planned_mm": project.get("total_planned_mm"),
                    "labor_cost_krw": project.get("labor_cost_krw"),
                    "average_unit_cost_krw_per_mm": project.get("average_unit_cost_krw_per_mm"),
                    "revenue_minus_labor_cost_krw": project.get("revenue_minus_labor_cost_krw"),
                    "labor_cost_ratio": project.get("labor_cost_ratio"),
                    "single_allocation_validation": project.get("single_allocation_validation"),
                    "technology_tags": project.get("technology_tags", []),
                },
            }
        )
    return projects


def build_memberships(dataset: dict[str, Any]) -> list[dict[str, Any]]:
    memberships: list[dict[str, Any]] = []
    for assignment in dataset["assignments"]:
        role = normalized_project_role(assignment.get("assignment_role"))
        memberships.append(
            {
                "assignment_id": assignment["assignment_id"],
                "project_id": assignment["project_id"],
                "user_id": assignment["user_id"],
                "employee_no": assignment["employee_no"],
                "name": assignment["name"],
                "project_role": role,
                "allocation_percent": assignment["allocation_percent"],
                "planned_mm": assignment["planned_mm"],
                "annual_salary_krw": assignment["annual_salary_krw"],
                "allocated_cost_krw": assignment["allocated_cost_krw"],
                "staffing_note": (
                    f"{assignment.get('assignment_role')} / "
                    f"{assignment.get('start_date')}~{assignment.get('end_date')} / "
                    f"{assignment.get('assignment_status')} / "
                    f"{assignment.get('note')}"
                ),
                "metadata": {
                    "assignment_role": assignment.get("assignment_role"),
                    "assignment_status": assignment.get("assignment_status"),
                    "division": assignment.get("division"),
                    "team": assignment.get("team"),
                    "position": assignment.get("position"),
                    "unit_cost_krw_per_mm": assignment.get("unit_cost_krw_per_mm"),
                    "source_note": assignment.get("note"),
                    "start_date": assignment.get("start_date"),
                    "end_date": assignment.get("end_date"),
                },
            }
        )
    return memberships


def summarize(
    dataset: dict[str, Any],
    users: list[dict[str, Any]],
    projects: list[dict[str, Any]],
    memberships: list[dict[str, Any]],
) -> dict[str, Any]:
    positions: dict[str, int] = {}
    duties: dict[str, int] = {}
    project_sizes: dict[str, int] = {}
    project_planned_mm: dict[str, float] = {}
    project_allocation_percent: dict[str, float] = {}
    for user in users:
        positions[user["position"]] = positions.get(user["position"], 0) + 1
        duties[user["duty"]] = duties.get(user["duty"], 0) + 1
    for membership in memberships:
        project_id = membership["project_id"]
        project_sizes[project_id] = project_sizes.get(project_id, 0) + 1
        project_planned_mm[project_id] = round(project_planned_mm.get(project_id, 0) + membership["planned_mm"], 2)
        project_allocation_percent[project_id] = round(
            project_allocation_percent.get(project_id, 0) + membership["allocation_percent"],
            2,
        )
    summary = dict(dataset["summary"])
    summary.update(
        {
            "positions": positions,
            "duties": duties,
            "project_sizes": project_sizes,
            "project_planned_mm": project_planned_mm,
            "project_allocation_percent": project_allocation_percent,
            "total_annual_salary_krw": sum(user["annual_salary_krw"] for user in users),
            "account_count": len(users),
            "login_id_match_count": sum(1 for user in users if user["login_id"] == user["employee_no"]),
            "initial_password_1234_count": sum(1 for user in users if user["initial_password"] == INITIAL_PASSWORD),
        }
    )
    return summary


def build_company_plan(dataset_path: Path = DATASET_PATH) -> dict[str, Any]:
    dataset = load_dataset(dataset_path)
    users = build_users(dataset)
    projects = build_projects(dataset)
    memberships = build_memberships(dataset)
    company = dict(dataset["company"])
    company["annual_revenue_label"] = revenue_label(company["annual_revenue_krw"])
    plan = {
        "source": dataset["source"],
        "company": company,
        "org_units": dataset["org_units"],
        "users": users,
        "projects": projects,
        "project_memberships": memberships,
    }
    plan["summary"] = summarize(dataset, users, projects, memberships)
    return plan


def write_plan(plan: dict[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_plan(plan: dict[str, Any]) -> None:
    company = plan["company"]
    summary = plan["summary"]
    assert company["company_id"] == "SSK-TECH", company
    assert company["company_name"] == "새싹테크솔루션 주식회사", company
    assert company["annual_revenue_krw"] == 10_000_000_000, company
    assert summary["headcount"] == 50, summary
    assert summary["management_headcount"] == 10, summary
    assert summary["research_headcount"] == 15, summary
    assert summary["development_headcount"] == 25, summary
    assert summary["project_count"] == 15, summary
    assert summary["account_count"] == 50, summary
    assert summary["login_id_match_count"] == 50, summary
    assert summary["initial_password_1234_count"] == 50, summary
    assert summary["assignment_count"] == 207, summary
    assert summary["total_planned_mm"] == 50, summary
    assert summary["total_labor_cost_krw"] == 432_000_000, summary
    assert summary["employee_planned_mm_min"] == 1, summary
    assert summary["employee_planned_mm_max"] == 1, summary
    assert summary["employee_planned_mm_not_one_count"] == 0, summary
    assert summary["max_single_planned_mm"] == 0.6, summary
    assert summary["division_count"] == 3, summary
    assert summary["team_count"] == 11, summary
    assert not summary["duplicate_assignment_keys"], summary["duplicate_assignment_keys"]
    assert not summary["missing_project_pms"], summary["missing_project_pms"]
    assert len({user["name"] for user in plan["users"]}) == 50, plan["users"]
    assert all(user["annual_salary_krw"] > 0 for user in plan["users"]), plan["users"]
    assert all(user["login_id"] == user["employee_no"] for user in plan["users"]), plan["users"]
    assert all(user["initial_password"] == INITIAL_PASSWORD for user in plan["users"]), plan["users"]
    assert all(user.get("auth_group") for user in plan["users"]), plan["users"]
    project_ids = {project["project_id"] for project in plan["projects"]}
    user_ids = {user["user_id"] for user in plan["users"]}
    expected_project_sizes = summary["project_assignment_counts"]
    for project in plan["projects"]:
        assert project["pm_user_id"] in user_ids, project
        assert expected_project_sizes[project["project_id"]] == project["metadata"]["registered_employee_count"], project
    for membership in plan["project_memberships"]:
        assert membership["project_id"] in project_ids, membership
        assert membership["user_id"] in user_ids, membership
        assert 0 <= membership["allocation_percent"] <= 100, membership
        assert membership["planned_mm"] >= 0, membership
        assert membership["allocated_cost_krw"] >= 0, membership


def apply_plan(plan: dict[str, Any], password: str, status: str) -> dict[str, Any]:
    override_password = password != INITIAL_PASSWORD
    company = plan["company"]
    users = plan["users"]
    projects = plan["projects"]
    memberships = plan["project_memberships"]

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
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
                """,
                (
                    company["company_id"],
                    company["company_name"],
                    company.get("english_name"),
                    company.get("industry"),
                    company.get("founded_on"),
                    company.get("headquarters"),
                    company.get("ceo"),
                    company.get("fiscal_year"),
                    company.get("annual_revenue_krw"),
                    company.get("headcount"),
                    company.get("project_count"),
                    company.get("organization_summary"),
                    company.get("headcount_summary"),
                    company.get("note"),
                    plan.get("source", {}).get("file_name"),
                    Jsonb(
                        {
                            "annual_revenue_label": company.get("annual_revenue_label"),
                            "org_units": plan.get("org_units", []),
                            "summary": plan.get("summary", {}),
                            "source": plan.get("source", {}),
                        }
                    ),
                ),
            )

            for user in users:
                seed_password = password if override_password else user.get("initial_password") or password
                cursor.execute(
                    """
                    INSERT INTO users
                        (user_id, employee_no, name, email, role, password_hash, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (employee_no)
                    DO UPDATE SET
                        name = EXCLUDED.name,
                        email = EXCLUDED.email,
                        role = EXCLUDED.role,
                        password_hash = EXCLUDED.password_hash,
                        status = EXCLUDED.status,
                        updated_at = now()
                    """,
                    (
                        user["user_id"],
                        user["employee_no"],
                        user["name"],
                        user["email"],
                        user["role"],
                        hash_password(seed_password),
                        status,
                    ),
                )
                cursor.execute(
                    """
                    INSERT INTO resource_profiles
                        (resource_id, resource_type, resource_name, capacity, unit, location,
                         owner_user_id, status, metadata, created_by)
                    VALUES (%s, 'human', %s, 1, 'person', %s, %s, 'active', %s, %s)
                    ON CONFLICT (resource_id)
                    DO UPDATE SET
                        resource_name = EXCLUDED.resource_name,
                        location = EXCLUDED.location,
                        owner_user_id = EXCLUDED.owner_user_id,
                        status = EXCLUDED.status,
                        metadata = EXCLUDED.metadata,
                        updated_at = now()
                    """,
                    (
                        user["resource_id"],
                        user["name"],
                        user["division_name"],
                        user["user_id"],
                        Jsonb(user["metadata"]),
                        user["user_id"],
                    ),
                )

            for project in projects:
                cursor.execute(
                    """
                    INSERT INTO projects (project_id, name, description, status, pm_user_id)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (project_id)
                    DO UPDATE SET
                        name = EXCLUDED.name,
                        description = EXCLUDED.description,
                        status = EXCLUDED.status,
                        pm_user_id = EXCLUDED.pm_user_id
                    """,
                    (
                        project["project_id"],
                        project["name"],
                        project["description"],
                        project["status"],
                        project["pm_user_id"],
                    ),
                )

            project_ids = [project["project_id"] for project in projects]
            cursor.execute("DELETE FROM project_members WHERE project_id = ANY(%s)", (project_ids,))
            for membership in memberships:
                cursor.execute(
                    """
                    INSERT INTO project_members
                        (project_id, user_id, project_role, allocation_percent, planned_mm,
                         staffing_note, annual_salary_krw, allocated_cost_krw)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        membership["project_id"],
                        membership["user_id"],
                        membership["project_role"],
                        membership["allocation_percent"],
                        membership["planned_mm"],
                        membership["staffing_note"],
                        membership["annual_salary_krw"],
                        membership["allocated_cost_krw"],
                    ),
                )

            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (NULL, 'seed_demo_company', 'company_fixture', %s, NULL, %s)
                """,
                (
                    plan["company"]["company_id"],
                    Jsonb(
                        {
                            "company": plan["company"],
                            "summary": plan["summary"],
                            "source": plan["source"],
                            "seed_policy": "upsert_users_resources_projects_project_members_with_employee_no_login",
                        }
                    ),
                ),
            )

    return {
        "applied": True,
        "company_id": company["company_id"],
        "users": len(users),
        "projects": len(projects),
        "project_memberships": len(memberships),
        "status": status,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build or apply the Saessak Tech Solutions demo fixture.")
    parser.add_argument("--apply", action="store_true", help="Persist the fixture to the configured Platform DB.")
    parser.add_argument("--dataset", type=Path, default=DATASET_PATH, help="Company fixture JSON dataset path.")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH, help="Write the generated plan JSON to this path.")
    parser.add_argument("--password", default=INITIAL_PASSWORD, help="Initial password for seeded users when --apply is used.")
    parser.add_argument(
        "--status",
        choices=[status.value for status in AccountStatus],
        default=AccountStatus.ACTIVE.value,
        help="Seeded account status when --apply is used.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    plan = build_company_plan(args.dataset)
    validate_plan(plan)
    write_plan(plan, args.output)
    result: dict[str, Any] = {
        "applied": False,
        "output": str(args.output),
        "summary": plan["summary"],
    }
    if args.apply:
        result.update(apply_plan(plan, args.password, args.status))
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()

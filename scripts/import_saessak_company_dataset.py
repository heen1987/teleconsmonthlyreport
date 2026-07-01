#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import pandas as pd


DEFAULT_INPUT = (
    Path("G:/내 드라이브/새싹교육_프로젝트/새싹교육_프로젝트 1")
    / "7. 가상회사_새싹테크솔루션"
    / "saessak_virtual_company_dataset_pms_login_revised.xlsx"
)
DEFAULT_OUTPUT = Path("scripts/data/saessak_company_dataset.json")


def is_empty(value: Any) -> bool:
    return value is None or (isinstance(value, float) and math.isnan(value)) or pd.isna(value)


def clean_text(value: Any) -> str | None:
    if is_empty(value):
        return None
    text = str(value).strip()
    if text.endswith(".0") and text[:-2].isdigit():
        text = text[:-2]
    return text or None


def to_int(value: Any, default: int = 0) -> int:
    if is_empty(value):
        return default
    return int(round(float(value)))


def to_float(value: Any, digits: int | None = None, default: float = 0.0) -> float:
    if is_empty(value):
        return default
    number = float(value)
    return round(number, digits) if digits is not None else number


def to_date(value: Any) -> str | None:
    if is_empty(value):
        return None
    if isinstance(value, pd.Timestamp):
        return value.date().isoformat()
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, (int, float)):
        return (datetime(1899, 12, 30) + timedelta(days=int(value))).date().isoformat()
    parsed = pd.to_datetime(value, errors="coerce")
    if pd.isna(parsed):
        return clean_text(value)
    return parsed.date().isoformat()


def split_tags(value: Any) -> list[str]:
    text = clean_text(value)
    if not text:
        return []
    return [part.strip() for part in text.split(",") if part.strip()]


def status_code(value: Any) -> str:
    text = clean_text(value)
    return {"진행중": "active", "완료": "completed", "예정": "planned", "보류": "on_hold"}.get(
        text or "",
        "active",
    )


def priority_code(value: Any) -> str:
    text = clean_text(value)
    return {"높음": "high", "보통": "medium", "낮음": "low"}.get(text or "", "medium")


def app_role(account_row: dict[str, Any], employee_row: dict[str, Any]) -> str:
    auth_group = (clean_text(account_row.get("권한그룹")) or "").upper()
    team = clean_text(employee_row.get("팀")) or ""
    duty = clean_text(employee_row.get("직책")) or ""
    if auth_group == "ADMIN":
        return "admin"
    if team == "재무팀":
        return "finance"
    if team == "인사팀" or "HR" in duty or "인사" in duty:
        return "resource_manager"
    if auth_group == "LEAD":
        return "pl"
    if auth_group == "MANAGER":
        return "pm"
    return "member"


def read_company_pairs(xlsx_path: Path) -> dict[str, Any]:
    company_raw = pd.read_excel(xlsx_path, sheet_name="회사개요", header=None)
    pairs: dict[str, Any] = {}
    for _, row in company_raw.iterrows():
        key = clean_text(row.iloc[0])
        value = row.iloc[1] if len(row) > 1 else None
        if key and key not in {"새싹테크솔루션 주식회사 회사개요", "항목"}:
            pairs[key] = value
    return pairs


def build_dataset(xlsx_path: Path) -> dict[str, Any]:
    company_pairs = read_company_pairs(xlsx_path)
    accounts = pd.read_excel(xlsx_path, sheet_name="사용자계정").dropna(how="all")
    employees_df = pd.read_excel(xlsx_path, sheet_name="직원명부").dropna(how="all")
    org_df = pd.read_excel(xlsx_path, sheet_name="조직구성").dropna(how="all")
    projects_df = pd.read_excel(xlsx_path, sheet_name="프로젝트").dropna(how="all")
    assignments_df = pd.read_excel(xlsx_path, sheet_name="프로젝트배정").dropna(how="all")

    account_by_no = {clean_text(row["사번"]): row.to_dict() for _, row in accounts.iterrows()}
    employee_by_no = {clean_text(row["사번"]): row.to_dict() for _, row in employees_df.iterrows()}

    assignments_grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for _, row in assignments_df.iterrows():
        row_dict = row.to_dict()
        assignments_grouped[clean_text(row_dict["프로젝트ID"])].append(row_dict)

    org_units = [
        {
            "division": clean_text(row["본부"]),
            "team": clean_text(row["팀"]),
            "key_work": clean_text(row["주요업무"]),
            "target_headcount": to_int(row["목표정원"]),
            "current_headcount": to_int(row["현재인원"]),
            "leader": clean_text(row["책임자"]),
            "note": clean_text(row["비고"]),
        }
        for _, row in org_df.iterrows()
    ]

    employees: list[dict[str, Any]] = []
    for _, row in employees_df.iterrows():
        employee = row.to_dict()
        employee_no = clean_text(employee["사번"])
        account = account_by_no[employee_no]
        employees.append(
            {
                "user_id": f"USR-{employee_no}",
                "employee_no": employee_no,
                "login_id": clean_text(account.get("로그인ID")) or employee_no,
                "initial_password": clean_text(account.get("초기비밀번호")) or "1234",
                "name": clean_text(employee["성명"]),
                "email": clean_text(employee.get("이메일")),
                "account_role": app_role(account, employee),
                "auth_group": clean_text(account.get("권한그룹")),
                "account_status": clean_text(account.get("계정상태")),
                "login_method": clean_text(account.get("로그인방식")),
                "account_note": clean_text(account.get("비고")),
                "division": clean_text(employee["본부"]),
                "team": clean_text(employee["팀"]),
                "position": clean_text(employee["직급"]),
                "duty": clean_text(employee["직책"]),
                "employment_type": clean_text(employee.get("고용형태")),
                "hire_date": to_date(employee.get("입사일")),
                "phone": clean_text(employee.get("전화")),
                "location": clean_text(employee.get("근무지")),
                "skill_tags": split_tags(employee.get("역량태그")),
                "primary_project": clean_text(employee.get("주 담당 프로젝트")),
                "total_planned_mm": to_float(employee.get("투입M/M 합계"), 6),
                "total_allocation_rate": to_float(employee.get("투입M/M 합계"), 6),
                "annual_salary_krw": to_int(employee.get("연봉(만원)")) * 10_000,
                "status_text": clean_text(employee.get("상태")),
                "resource_id": f"RES-{employee_no}",
            }
        )

    projects: list[dict[str, Any]] = []
    for _, row in projects_df.iterrows():
        project = row.to_dict()
        project_id = clean_text(project["프로젝트ID"])
        grouped = assignments_grouped[project_id]
        total_planned_mm = round(sum(to_float(item.get("투입M/M"), 6) for item in grouped), 6)
        labor_cost_krw = sum(to_int(item.get("투입금액(원)")) for item in grouped)
        revenue = to_int(project.get("매출배분(원)"))
        projects.append(
            {
                "project_id": project_id,
                "project_name": clean_text(project["프로젝트명"]),
                "division": clean_text(project["담당본부"]),
                "team": clean_text(project["담당팀"]),
                "pm_employee_no": clean_text(project["PM사번"]),
                "pm_name": clean_text(project["PM명"]),
                "pm_user_id": f"USR-{clean_text(project['PM사번'])}",
                "status_text": clean_text(project["상태"]),
                "status_code": status_code(project.get("상태")),
                "priority_text": clean_text(project["우선순위"]),
                "priority_code": priority_code(project.get("우선순위")),
                "start_date": to_date(project.get("시작일")),
                "end_date": to_date(project.get("종료일")),
                "duration_months": to_float(project.get("기간(개월)"), 6),
                "registered_employee_count": len({clean_text(item.get("사번(로그인ID)")) for item in grouped}),
                "revenue_allocation_krw": revenue,
                "revenue_share": to_float(project.get("매출비중"), 6),
                "technologies_text": clean_text(project.get("주요기술")),
                "technology_tags": split_tags(project.get("주요기술")),
                "description": clean_text(project.get("목표/설명")),
                "total_planned_mm": total_planned_mm,
                "labor_cost_krw": labor_cost_krw,
                "average_unit_cost_krw_per_mm": round(labor_cost_krw / total_planned_mm, 6)
                if total_planned_mm
                else 0,
                "revenue_minus_labor_cost_krw": revenue - labor_cost_krw,
                "labor_cost_ratio": round(labor_cost_krw / revenue, 6) if revenue else 0,
                "single_allocation_validation": clean_text(project.get("단일투입검증")),
            }
        )

    assignments: list[dict[str, Any]] = []
    for index, (_, row) in enumerate(assignments_df.iterrows(), start=1):
        assignment = row.to_dict()
        employee_no = clean_text(assignment["사번(로그인ID)"])
        employee = employee_by_no[employee_no]
        planned_mm = to_float(assignment.get("투입M/M"), 6)
        assignments.append(
            {
                "assignment_id": f"A{index:04d}",
                "project_id": clean_text(assignment["프로젝트ID"]),
                "project_name": clean_text(assignment["프로젝트명"]),
                "user_id": f"USR-{employee_no}",
                "employee_no": employee_no,
                "name": clean_text(assignment["성명"]),
                "division": clean_text(assignment["본부"]),
                "team": clean_text(assignment["팀"]),
                "position": clean_text(assignment["직급"]),
                "assignment_role": clean_text(assignment["역할"]),
                "project_role": clean_text(assignment["역할"]),
                "planned_mm": planned_mm,
                "allocation_rate": planned_mm,
                "allocation_percent": round(planned_mm * 100, 6),
                "unit_cost_krw_per_mm": to_int(assignment.get("단가(원/1M)")),
                "allocated_cost_krw": to_int(assignment.get("투입금액(원)")),
                "annual_salary_krw": to_int(employee.get("연봉(만원)")) * 10_000,
                "start_date": to_date(assignment.get("시작일")),
                "end_date": to_date(assignment.get("종료일")),
                "assignment_status": clean_text(assignment.get("배정상태")),
                "note": clean_text(assignment.get("비고")),
            }
        )

    headcount_by_division = dict(sorted(Counter(employee["division"] for employee in employees).items()))
    project_count_by_division = dict(sorted(Counter(project["division"] for project in projects).items()))
    project_assignment_counts = {project["project_id"]: 0 for project in projects}
    project_planned_mm_sum = {project["project_id"]: 0.0 for project in projects}
    project_labor_cost_sum_krw = {project["project_id"]: 0 for project in projects}
    for assignment in assignments:
        project_id = assignment["project_id"]
        project_assignment_counts[project_id] += 1
        project_planned_mm_sum[project_id] = round(project_planned_mm_sum[project_id] + assignment["planned_mm"], 6)
        project_labor_cost_sum_krw[project_id] += assignment["allocated_cost_krw"]

    assignment_key_counts = Counter((item["project_id"], item["employee_no"]) for item in assignments)
    duplicate_assignment_keys = [
        f"{project_id}:{employee_no}" for (project_id, employee_no), count in assignment_key_counts.items() if count > 1
    ]
    project_ids = {project["project_id"] for project in projects}
    missing_project_pms = sorted({item["project_id"] for item in assignments if item["project_id"] not in project_ids})
    employee_planned_mm = [employee["total_planned_mm"] for employee in employees]

    summary = {
        "headcount": len(employees),
        "management_headcount": headcount_by_division.get("경영본부", 0),
        "research_headcount": headcount_by_division.get("연구소", 0),
        "development_headcount": headcount_by_division.get("개발본부", 0),
        "headcount_by_division": headcount_by_division,
        "project_count": len(projects),
        "project_count_by_division": project_count_by_division,
        "assignment_count": len(assignments),
        "total_planned_mm": round(sum(item["planned_mm"] for item in assignments), 6),
        "total_labor_cost_krw": sum(item["allocated_cost_krw"] for item in assignments),
        "employee_planned_mm_min": min(employee_planned_mm),
        "employee_planned_mm_max": max(employee_planned_mm),
        "employee_planned_mm_not_one_count": sum(1 for value in employee_planned_mm if round(value, 6) != 1),
        "max_single_planned_mm": max(item["planned_mm"] for item in assignments),
        "division_count": len(headcount_by_division),
        "team_count": len({(employee["division"], employee["team"]) for employee in employees}),
        "project_assignment_counts": project_assignment_counts,
        "project_allocation_sum": project_planned_mm_sum,
        "project_planned_mm_sum": project_planned_mm_sum,
        "project_labor_cost_sum_krw": project_labor_cost_sum_krw,
        "duplicate_assignment_keys": duplicate_assignment_keys,
        "missing_project_pms": missing_project_pms,
        "total_annual_salary_krw": sum(employee["annual_salary_krw"] for employee in employees),
        "account_count": len(accounts),
        "login_id_match_count": sum(1 for employee in employees if employee["login_id"] == employee["employee_no"]),
        "initial_password_1234_count": sum(1 for employee in employees if employee["initial_password"] == "1234"),
        "auth_group_counts": dict(sorted(Counter(employee["auth_group"] for employee in employees).items())),
        "account_role_counts": dict(sorted(Counter(employee["account_role"] for employee in employees).items())),
        "account_status_counts": dict(sorted(Counter(employee["account_status"] for employee in employees).items())),
        "login_method_counts": dict(sorted(Counter(employee["login_method"] for employee in employees).items())),
    }

    company = {
        "company_id": "SSK-TECH",
        "company_name": clean_text(company_pairs.get("회사명")),
        "english_name": clean_text(company_pairs.get("영문명")),
        "industry": clean_text(company_pairs.get("업종")),
        "founded_on": to_date(company_pairs.get("설립일")),
        "headquarters": clean_text(company_pairs.get("본사")),
        "ceo": clean_text(company_pairs.get("대표이사")),
        "fiscal_year": clean_text(company_pairs.get("회계연도")),
        "annual_revenue_krw": to_int(company_pairs.get("연매출")),
        "headcount": to_int(company_pairs.get("총 직원 수")),
        "project_count": to_int(company_pairs.get("총 프로젝트 수")),
        "organization_summary": clean_text(company_pairs.get("조직")),
        "headcount_summary": clean_text(company_pairs.get("인원 배치")),
        "note": clean_text(company_pairs.get("비고")),
    }

    return {
        "source": {
            "file_name": xlsx_path.name,
            "extracted_at": datetime.now().replace(microsecond=0).isoformat(),
            "source_path_note": "User-provided Google Drive workbook path; Korean path omitted for cross-platform parsing.",
            "login_policy": "직원은 사번을 로그인ID로 사용하고 초기비밀번호는 교육용 1234로 통일한다.",
        },
        "company": company,
        "org_units": org_units,
        "employees": employees,
        "projects": projects,
        "assignments": assignments,
        "summary": summary,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import the Saessak virtual company workbook into JSON fixture data.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Source workbook path.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Output JSON fixture path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    dataset = build_dataset(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(dataset, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "output": str(args.output),
                "source": dataset["source"]["file_name"],
                "employees": len(dataset["employees"]),
                "projects": len(dataset["projects"]),
                "assignments": len(dataset["assignments"]),
                "account_count": dataset["summary"]["account_count"],
                "login_id_match_count": dataset["summary"]["login_id_match_count"],
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()

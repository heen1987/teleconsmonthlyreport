#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_PATH="runtime/demo_company/latest_plan.json"
PYTHON_BIN="backend/.venv/bin/python"
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*)
    if [ -x "backend/.venv-win/Scripts/python.exe" ]; then
      PYTHON_BIN="backend/.venv-win/Scripts/python.exe"
    fi
    ;;
esac
if [ ! -x "$PYTHON_BIN" ] && [ -x "backend/.venv-win/Scripts/python.exe" ]; then
  PYTHON_BIN="backend/.venv-win/Scripts/python.exe"
fi

"$PYTHON_BIN" scripts/seed_demo_company.py --output "$OUTPUT_PATH" >/tmp/ai_pms_demo_company_seed.json

"$PYTHON_BIN" - <<'PY'
import json
from pathlib import Path

plan = json.loads(Path("runtime/demo_company/latest_plan.json").read_text(encoding="utf-8"))
summary = plan["summary"]

assert plan["company"]["company_name"] == "새싹테크솔루션 주식회사", plan["company"]
assert plan["company"]["annual_revenue_krw"] == 10_000_000_000, plan["company"]
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
assert summary["total_annual_salary_krw"] > 0, summary
assert not summary["duplicate_assignment_keys"], summary
assert not summary["missing_project_pms"], summary
assert len({user["name"] for user in plan["users"]}) == 50, plan["users"]
assert all(user["annual_salary_krw"] > 0 for user in plan["users"]), plan["users"]
assert all(user["login_id"] == user["employee_no"] for user in plan["users"]), plan["users"]
assert all(user["initial_password"] == "1234" for user in plan["users"]), plan["users"]
assert all(user.get("auth_group") for user in plan["users"]), plan["users"]

assert set(summary["positions"]) == {"대표이사", "사원", "선임", "책임", "수석"}, summary["positions"]
assert summary["duties"]["대표이사"] == 1, summary["duties"]
assert summary["duties"]["연구소장"] == 1, summary["duties"]
assert len(plan["projects"]) == 15, plan["projects"]
assert summary["project_sizes"] == summary["project_assignment_counts"], summary["project_sizes"]
assert sum(summary["project_sizes"].values()) == 207, summary["project_sizes"]
assert summary["project_planned_mm"] == summary["project_planned_mm_sum"], summary["project_planned_mm"]

project_ids = {project["project_id"] for project in plan["projects"]}
user_ids = {user["user_id"] for user in plan["users"]}
project_roles = {}
for membership in plan["project_memberships"]:
    assert membership["project_id"] in project_ids, membership
    assert membership["user_id"] in user_ids, membership
    assert 0 <= membership["allocation_percent"] <= 100, membership
    assert membership["planned_mm"] >= 0, membership
    assert membership["annual_salary_krw"] > 0, membership
    assert membership["allocated_cost_krw"] > 0, membership
    project_roles[membership["project_role"]] = project_roles.get(membership["project_role"], 0) + 1
assert project_roles["pm"] >= 1, project_roles

print(json.dumps({
    "company": plan["company"]["company_name"],
    "headcount": summary["headcount"],
    "management_headcount": summary["management_headcount"],
    "research_headcount": summary["research_headcount"],
    "development_headcount": summary["development_headcount"],
    "projects": summary["project_count"],
    "accounts": summary["account_count"],
    "login_id_match_count": summary["login_id_match_count"],
    "initial_password_1234_count": summary["initial_password_1234_count"],
    "project_memberships": summary["assignment_count"],
    "total_planned_mm": summary["total_planned_mm"],
    "total_labor_cost_krw": summary["total_labor_cost_krw"],
    "total_annual_salary_krw": summary["total_annual_salary_krw"],
}, ensure_ascii=False, sort_keys=True))
PY

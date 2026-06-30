#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_PATH="runtime/demo_company/latest_plan.json"
backend/.venv/bin/python scripts/seed_demo_company.py --output "$OUTPUT_PATH" >/tmp/ai_pms_demo_company_seed.json

backend/.venv/bin/python - <<'PY'
import json
from pathlib import Path

plan = json.loads(Path("runtime/demo_company/latest_plan.json").read_text(encoding="utf-8"))
summary = plan["summary"]

assert plan["company"]["company_name"] == "새싹SW", plan["company"]
assert plan["company"]["annual_revenue_krw"] == 5_000_000_000, plan["company"]
assert summary["headcount"] == 50, summary
assert summary["developer_headcount"] == 45, summary
assert summary["management_headcount"] == 5, summary
assert summary["project_count"] == 15, summary
assert summary["division_count"] == 4, summary
assert summary["total_annual_salary_krw"] > 0, summary
assert summary["developer_annual_salary_krw"] > 0, summary
assert len({user["name"] for user in plan["users"]}) == 50, plan["users"]
assert all(user["annual_salary_krw"] > 0 for user in plan["users"]), plan["users"]

assert summary["divisions"]["MGT"]["headcount"] == 5, summary["divisions"]
for division_code in ("RND", "DEV1", "DEV2"):
    division = summary["divisions"][division_code]
    assert division["headcount"] == 15, division
    assert division["developer_headcount"] == 15, division

assert set(summary["positions"]) == {"사원", "선임", "책임", "수석", "이사"}, summary["positions"]
assert summary["duties"]["대표이사"] == 1, summary["duties"]
assert summary["duties"]["팀장"] == 10, summary["duties"]
assert summary["duties"]["실장"] == 6, summary["duties"]
assert summary["duties"]["본부장"] == 2, summary["duties"]
assert summary["duties"]["연구소장"] == 1, summary["duties"]
assert len(plan["projects"]) == 15, plan["projects"]
assert all(size == 3 for size in summary["project_sizes"].values()), summary["project_sizes"]
assert all(mm == 2.4 for mm in summary["project_planned_mm"].values()), summary["project_planned_mm"]
assert all(percent == 240.0 for percent in summary["project_allocation_percent"].values()), summary["project_allocation_percent"]

project_ids = {project["project_id"] for project in plan["projects"]}
for membership in plan["project_memberships"]:
    assert membership["project_id"] in project_ids, membership
    assert membership["project_role"] in {"project_lead", "technical_lead", "developer"}, membership
    assert membership["allocation_percent"] in {60.0, 80.0, 100.0}, membership
    assert membership["planned_mm"] in {0.6, 0.8, 1.0}, membership
    assert membership["annual_salary_krw"] > 0, membership
    assert membership["allocated_cost_krw"] > 0, membership

print(json.dumps({
    "company": plan["company"]["company_name"],
    "headcount": summary["headcount"],
    "developer_headcount": summary["developer_headcount"],
    "projects": summary["project_count"],
    "project_memberships": summary["project_member_count"],
    "total_annual_salary_krw": summary["total_annual_salary_krw"],
}, ensure_ascii=False, sort_keys=True))
PY

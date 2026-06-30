#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "backend"))

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import AccountStatus
from app.services.passwords import hash_password


COMPANY_ID = "SSK-SW"
COMPANY_NAME = "새싹SW"
ANNUAL_REVENUE_KRW = 5_000_000_000
INITIAL_PASSWORD = "1234"
OUTPUT_PATH = ROOT_DIR / "runtime" / "demo_company" / "latest_plan.json"


@dataclass(frozen=True)
class DivisionSpec:
    code: str
    name: str
    kind: str
    description: str


MANAGEMENT_DIVISION = DivisionSpec(
    code="MGT",
    name="경영본부",
    kind="management",
    description="대표이사와 경영관리팀 4명으로 구성된 경영/관리 조직",
)

DEVELOPMENT_DIVISIONS = [
    DivisionSpec(
        code="RND",
        name="AI연구소",
        kind="development",
        description="회의 음성, STT, LLM 분석, 지식화 연구 수행조직",
    ),
    DivisionSpec(
        code="DEV1",
        name="플랫폼개발본부",
        kind="development",
        description="PMS, Platform API, 데이터/운영 백엔드 수행조직",
    ),
    DivisionSpec(
        code="DEV2",
        name="서비스개발본부",
        kind="development",
        description="웹, 앱, 외부접속, UX/API 연동 수행조직",
    ),
]

DEV_PROJECT_NAMES = {
    "RND": [
        "AI 회의록 분석 엔진 고도화",
        "경량 LLM 운영 파이프라인",
        "음성 STT 품질 평가 자동화",
        "프로젝트 지식그래프 PoC",
        "회의 요약 신뢰도 검증",
    ],
    "DEV1": [
        "PMS 플랫폼 API 고도화",
        "인증/권한 및 감사로그 구축",
        "프로젝트 리소스 관리 모듈",
        "운영 큐 및 재처리 자동화",
        "ERP 비용 연계 인터페이스",
    ],
    "DEV2": [
        "Android 회의 녹음 앱",
        "웹 리뷰 콘솔 시각화",
        "태블릿/휴대폰 반응형 UX",
        "외부 공개 검토 패키지",
        "회의 결과 자동 배포 UX",
    ],
}

MANAGEMENT_PEOPLE = [
    ("0001", "김도현", "대표이사실", "이사", "대표이사", "admin"),
    ("0002", "박서연", "경영관리팀", "책임", "팀장", "admin"),
    ("0003", "이민재", "경영관리팀", "선임", "재무담당", "finance"),
    ("0004", "최유진", "경영관리팀", "사원", "인사총무", "member"),
    ("0005", "정하늘", "경영관리팀", "사원", "경영지원", "finance"),
]

DEV_PEOPLE_TEMPLATE = [
    ("01", "이사", "본부장", "pm"),
    ("02", "수석", "실장", "pm"),
    ("03", "수석", "실장", "resource_manager"),
    ("04", "책임", "팀장", "pm"),
    ("05", "책임", "팀장", "pm"),
    ("06", "책임", "팀장", "pl"),
    ("07", "선임", "개발자", "pl"),
    ("08", "선임", "개발자", "pl"),
    ("09", "선임", "개발자", "pl"),
    ("10", "선임", "개발자", "pl"),
    ("11", "사원", "개발자", "member"),
    ("12", "사원", "개발자", "member"),
    ("13", "사원", "개발자", "member"),
    ("14", "사원", "개발자", "member"),
    ("15", "사원", "개발자", "member"),
]

DEV_NAMES_BY_DIVISION = {
    "RND": [
        "강태준",
        "송하린",
        "유민석",
        "문지아",
        "나현우",
        "오서윤",
        "정우빈",
        "하은별",
        "류시온",
        "권다빈",
        "임유찬",
        "서예나",
        "백지후",
        "최라온",
        "한도겸",
    ],
    "DEV1": [
        "조민규",
        "배지윤",
        "윤서준",
        "김하람",
        "차도윤",
        "신예린",
        "박건우",
        "이소율",
        "홍지호",
        "남가은",
        "전시우",
        "안유나",
        "구태양",
        "장서아",
        "노하준",
    ],
    "DEV2": [
        "이도현",
        "천수빈",
        "마준서",
        "성아린",
        "도윤재",
        "문채린",
        "서강우",
        "진하율",
        "황민재",
        "고예준",
        "라지민",
        "우서현",
        "표준영",
        "민가온",
        "한세아",
    ],
}

DIVISION_NAME_PREFIX = {
    "RND": "연구",
    "DEV1": "플랫폼",
    "DEV2": "서비스",
}

SALARY_BY_POSITION = {
    "사원": 42_000_000,
    "선임": 55_000_000,
    "책임": 70_000_000,
    "수석": 88_000_000,
    "이사": 118_000_000,
}

ROLE_ALLOCATION = {
    "project_lead": 60.0,
    "technical_lead": 80.0,
    "developer": 100.0,
}


def employee_no(code: str, seq: str) -> str:
    return f"{COMPANY_ID}-{code}-{seq}"


def user_id(code: str, seq: str) -> str:
    return f"USR-{COMPANY_ID}-{code}-{seq}"


def resource_id(code: str, seq: str) -> str:
    return f"RES-{COMPANY_ID}-{code}-{seq}"


def annual_salary_krw(position: str, duty: str, *, is_developer: bool, seq: str) -> int:
    if duty == "대표이사":
        return 180_000_000

    base_salary = SALARY_BY_POSITION[position]
    duty_allowance = {
        "본부장": 12_000_000,
        "연구소장": 12_000_000,
        "실장": 8_000_000,
        "팀장": 5_000_000,
        "재무담당": 2_000_000,
    }.get(duty, 0)
    developer_allowance = 3_000_000 if is_developer else 0
    deterministic_adjustment = (int(seq[-2:]) % 3) * 1_000_000
    return base_salary + duty_allowance + developer_allowance + deterministic_adjustment


def planned_mm_for(project_role: str) -> float:
    return round(ROLE_ALLOCATION[project_role] / 100, 2)


def allocated_cost_krw(annual_salary: int, planned_mm: float) -> int:
    return round(annual_salary * planned_mm / 12)


def build_user(
    *,
    division: DivisionSpec,
    seq: str,
    name: str,
    team_name: str,
    position: str,
    duty: str,
    role: str,
    is_developer: bool,
) -> dict[str, Any]:
    email_local = employee_no(division.code, seq).lower().replace("-", ".")
    salary = annual_salary_krw(position, duty, is_developer=is_developer, seq=seq)
    metadata = {
        "company_id": COMPANY_ID,
        "company_name": COMPANY_NAME,
        "annual_revenue_krw": ANNUAL_REVENUE_KRW,
        "annual_salary_krw": salary,
        "division_code": division.code,
        "division_name": division.name,
        "division_kind": division.kind,
        "team_name": team_name,
        "position": position,
        "duty": duty,
        "is_developer": is_developer,
        "salary_policy": "demo_position_based_salary",
        "position_ladder": ["사원", "선임", "책임", "수석", "이사"],
        "duty_ladder": {
            "팀장": "책임",
            "실장": "수석",
            "본부장": "이사",
        },
    }
    return {
        "user_id": user_id(division.code, seq),
        "employee_no": employee_no(division.code, seq),
        "name": name,
        "email": f"{email_local}@saessak-sw.local",
        "role": role,
        "status": AccountStatus.ACTIVE.value,
        "division_code": division.code,
        "division_name": division.name,
        "team_name": team_name,
        "position": position,
        "duty": duty,
        "is_developer": is_developer,
        "annual_salary_krw": salary,
        "resource_id": resource_id(division.code, seq),
        "metadata": metadata,
    }


def build_management_users() -> list[dict[str, Any]]:
    return [
        build_user(
            division=MANAGEMENT_DIVISION,
            seq=seq,
            name=name,
            team_name=team_name,
            position=position,
            duty=duty,
            role=role,
            is_developer=False,
        )
        for seq, name, team_name, position, duty, role in MANAGEMENT_PEOPLE
    ]


def build_development_users(division: DivisionSpec) -> list[dict[str, Any]]:
    prefix = DIVISION_NAME_PREFIX[division.code]
    users: list[dict[str, Any]] = []
    names = DEV_NAMES_BY_DIVISION[division.code]
    for seq, position, duty, role in DEV_PEOPLE_TEMPLATE:
        if duty == "본부장" and division.code == "RND":
            duty_label = "연구소장"
        else:
            duty_label = duty
        team_name = f"{prefix}{team_for_developer(seq)}"
        name = names[int(seq) - 1]
        users.append(
            build_user(
                division=division,
                seq=seq,
                name=name,
                team_name=team_name,
                position=position,
                duty=duty_label,
                role=role,
                is_developer=True,
            )
        )
    return users


def team_for_developer(seq: str) -> str:
    seq_no = int(seq)
    if seq_no <= 3:
        return "본부"
    if seq_no <= 6:
        return f"{seq_no - 3}팀"
    if seq_no <= 10:
        return f"{((seq_no - 7) % 3) + 1}팀"
    return f"{((seq_no - 11) % 3) + 1}팀"


def project_member_groups(users: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    return [
        [users[0], users[6], users[10]],
        [users[1], users[3], users[11]],
        [users[2], users[4], users[12]],
        [users[5], users[7], users[13]],
        [users[8], users[9], users[14]],
    ]


def project_role_for(index: int) -> str:
    return ["project_lead", "technical_lead", "developer"][index]


def build_projects(dev_users_by_division: dict[str, list[dict[str, Any]]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    projects: list[dict[str, Any]] = []
    memberships: list[dict[str, Any]] = []
    project_seq = 1
    for division in DEVELOPMENT_DIVISIONS:
        groups = project_member_groups(dev_users_by_division[division.code])
        for local_index, project_name in enumerate(DEV_PROJECT_NAMES[division.code], start=1):
            project_id = f"{COMPANY_ID}-PJT-{project_seq:02d}"
            group = groups[local_index - 1]
            projects.append(
                {
                    "project_id": project_id,
                    "name": project_name,
                    "status": "active",
                    "owning_division_code": division.code,
                    "owning_division_name": division.name,
                    "pm_user_id": group[0]["user_id"],
                }
            )
            for member_index, member in enumerate(group):
                memberships.append(
                    {
                        "project_id": project_id,
                        "user_id": member["user_id"],
                        "employee_no": member["employee_no"],
                        "name": member["name"],
                        "project_role": project_role_for(member_index),
                        "allocation_percent": ROLE_ALLOCATION[project_role_for(member_index)],
                        "planned_mm": planned_mm_for(project_role_for(member_index)),
                        "annual_salary_krw": member["annual_salary_krw"],
                        "allocated_cost_krw": allocated_cost_krw(
                            member["annual_salary_krw"],
                            planned_mm_for(project_role_for(member_index)),
                        ),
                        "staffing_note": f"{project_name} {project_role_for(member_index)} 배정",
                        "division_code": division.code,
                    }
                )
            project_seq += 1
    return projects, memberships


def summarize(users: list[dict[str, Any]], projects: list[dict[str, Any]], memberships: list[dict[str, Any]]) -> dict[str, Any]:
    divisions: dict[str, dict[str, Any]] = {}
    positions: dict[str, int] = {}
    duties: dict[str, int] = {}
    for user in users:
        division = divisions.setdefault(
            user["division_code"],
            {
                "division_name": user["division_name"],
                "headcount": 0,
                "developer_headcount": 0,
            },
        )
        division["headcount"] += 1
        if user["is_developer"]:
            division["developer_headcount"] += 1
        positions[user["position"]] = positions.get(user["position"], 0) + 1
        duties[user["duty"]] = duties.get(user["duty"], 0) + 1

    project_sizes: dict[str, int] = {}
    project_planned_mm: dict[str, float] = {}
    project_allocation_percent: dict[str, float] = {}
    for membership in memberships:
        project_sizes[membership["project_id"]] = project_sizes.get(membership["project_id"], 0) + 1
        project_planned_mm[membership["project_id"]] = round(
            project_planned_mm.get(membership["project_id"], 0) + membership["planned_mm"],
            2,
        )
        project_allocation_percent[membership["project_id"]] = round(
            project_allocation_percent.get(membership["project_id"], 0) + membership["allocation_percent"],
            2,
        )

    return {
        "headcount": len(users),
        "developer_headcount": sum(1 for user in users if user["is_developer"]),
        "management_headcount": sum(1 for user in users if not user["is_developer"]),
        "project_count": len(projects),
        "project_member_count": len(memberships),
        "division_count": len(divisions),
        "divisions": divisions,
        "positions": positions,
        "duties": duties,
        "project_sizes": project_sizes,
        "project_planned_mm": project_planned_mm,
        "project_allocation_percent": project_allocation_percent,
        "total_annual_salary_krw": sum(user["annual_salary_krw"] for user in users),
        "developer_annual_salary_krw": sum(user["annual_salary_krw"] for user in users if user["is_developer"]),
    }


def build_company_plan() -> dict[str, Any]:
    management_users = build_management_users()
    dev_users_by_division = {
        division.code: build_development_users(division)
        for division in DEVELOPMENT_DIVISIONS
    }
    dev_users = [user for users in dev_users_by_division.values() for user in users]
    users = management_users + dev_users
    projects, memberships = build_projects(dev_users_by_division)
    divisions = [MANAGEMENT_DIVISION, *DEVELOPMENT_DIVISIONS]
    plan = {
        "company": {
            "company_id": COMPANY_ID,
            "company_name": COMPANY_NAME,
            "industry": "SW 개발",
            "annual_revenue_krw": ANNUAL_REVENUE_KRW,
            "annual_revenue_label": "50억 원",
            "headcount": 50,
            "developer_headcount": 45,
            "project_count": 15,
            "position_ladder": ["사원", "선임", "책임", "수석", "이사"],
            "duty_mapping": {
                "팀장": "책임",
                "실장": "수석",
                "본부장": "이사",
            },
        },
        "divisions": [
            {
                "division_code": division.code,
                "division_name": division.name,
                "division_kind": division.kind,
                "description": division.description,
            }
            for division in divisions
        ],
        "users": users,
        "projects": projects,
        "project_memberships": memberships,
    }
    plan["summary"] = summarize(users, projects, memberships)
    return plan


def write_plan(plan: dict[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_plan(plan: dict[str, Any]) -> None:
    summary = plan["summary"]
    assert summary["headcount"] == 50, summary
    assert summary["developer_headcount"] == 45, summary
    assert summary["management_headcount"] == 5, summary
    assert summary["project_count"] == 15, summary
    assert summary["division_count"] == 4, summary
    assert plan["company"]["annual_revenue_krw"] == ANNUAL_REVENUE_KRW, plan["company"]
    for division_code in ["RND", "DEV1", "DEV2"]:
        assert summary["divisions"][division_code]["developer_headcount"] == 15, summary["divisions"][division_code]
    assert summary["divisions"]["MGT"]["headcount"] == 5, summary["divisions"]["MGT"]
    assert set(summary["positions"]) == {"사원", "선임", "책임", "수석", "이사"}, summary["positions"]
    assert all(size == 3 for size in summary["project_sizes"].values()), summary["project_sizes"]
    assert all(mm == 2.4 for mm in summary["project_planned_mm"].values()), summary["project_planned_mm"]
    assert all(percent == 240.0 for percent in summary["project_allocation_percent"].values()), summary["project_allocation_percent"]
    assert all(user["annual_salary_krw"] > 0 for user in plan["users"]), plan["users"]
    assert len({user["name"] for user in plan["users"]}) == 50, plan["users"]


def apply_plan(plan: dict[str, Any], password: str, status: str) -> dict[str, Any]:
    password_hash = hash_password(password)
    users = plan["users"]
    projects = plan["projects"]
    memberships = plan["project_memberships"]

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            for user in users:
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
                        password_hash,
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
                    INSERT INTO projects (project_id, name, status, pm_user_id)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (project_id)
                    DO UPDATE SET
                        name = EXCLUDED.name,
                        status = EXCLUDED.status,
                        pm_user_id = EXCLUDED.pm_user_id
                    """,
                    (project["project_id"], project["name"], project["status"], project["pm_user_id"]),
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
                    COMPANY_ID,
                    Jsonb(
                        {
                            "company": plan["company"],
                            "summary": plan["summary"],
                            "seed_policy": "upsert_users_projects_project_members",
                        }
                    ),
                ),
            )

    return {
        "applied": True,
        "users": len(users),
        "projects": len(projects),
        "project_memberships": len(memberships),
        "status": status,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build or apply the 50-person SW company demo fixture.")
    parser.add_argument("--apply", action="store_true", help="Persist the fixture to the configured Platform DB.")
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
    plan = build_company_plan()
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

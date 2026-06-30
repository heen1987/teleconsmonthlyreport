from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg.rows import dict_row

from app.db.session import get_connection
from app.schemas import (
    ProjectCreate,
    ProjectDashboardOut,
    ProjectDetailOut,
    ProjectKnowledgeItemOut,
    ProjectMemberAdd,
    ProjectMemberOut,
    ProjectOut,
    ProjectUpdate,
    ResourceDemandOut,
    TaskOut,
)
from app.services.auth_tokens import require_active_user

router = APIRouter(prefix="/projects", tags=["projects"], dependencies=[Depends(require_active_user)])


def _ensure_project_exists(cursor, project_id: str) -> None:
    cursor.execute("SELECT project_id FROM projects WHERE project_id = %s", (project_id,))
    if cursor.fetchone() is None:
        raise HTTPException(status_code=404, detail="Project not found")


def _fetch_project(cursor, project_id: str) -> dict:
    cursor.execute(
        """
        SELECT project_id, name, description, pm_user_id, status
        FROM projects
        WHERE project_id = %s
        """,
        (project_id,),
    )
    row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return row


def _fetch_project_members(cursor, project_id: str) -> list[ProjectMemberOut]:
    cursor.execute(
        """
        SELECT pm.project_id,
            u.user_id,
            u.employee_no,
            u.name,
            u.email,
            u.role AS user_role,
            pm.project_role,
            pm.allocation_percent,
            pm.planned_mm,
            pm.staffing_note,
            pm.annual_salary_krw,
            pm.allocated_cost_krw
        FROM project_members pm
        JOIN users u ON u.user_id = pm.user_id
        WHERE pm.project_id = %s
        ORDER BY pm.created_at ASC
        """,
        (project_id,),
    )
    return [ProjectMemberOut.model_validate(row) for row in cursor.fetchall()]


@router.post("", response_model=ProjectOut)
def create_project(payload: ProjectCreate):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                INSERT INTO projects (project_id, name, description, pm_user_id)
                VALUES (%s, %s, %s, %s)
                RETURNING project_id, name, description, pm_user_id, status
                """,
                (payload.project_id, payload.name, payload.description, payload.pm_user_id),
            )
            row = cursor.fetchone()
    return row


@router.get("", response_model=list[ProjectOut])
def list_projects():
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT project_id, name, description, pm_user_id, status
                FROM projects
                ORDER BY created_at DESC
                """
            )
            rows = cursor.fetchall()
    return rows


@router.get("/{project_id}", response_model=ProjectOut)
def get_project(project_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            return _fetch_project(cursor, project_id)


@router.put("/{project_id}", response_model=ProjectOut)
def update_project(project_id: str, payload: ProjectUpdate):
    fields_set = getattr(payload, "model_fields_set", set())
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            _ensure_project_exists(cursor, project_id)
            assignments: list[str] = []
            params: list[object] = []

            if "name" in fields_set and payload.name is not None:
                assignments.append("name = %s")
                params.append(payload.name)
            if "description" in fields_set:
                assignments.append("description = %s")
                params.append(payload.description)
            if "pm_user_id" in fields_set:
                assignments.append("pm_user_id = %s")
                params.append(payload.pm_user_id)

            if assignments:
                params.append(project_id)
                cursor.execute(
                    f"""
                    UPDATE projects
                    SET {", ".join(assignments)}
                    WHERE project_id = %s
                    RETURNING project_id, name, description, pm_user_id, status
                    """,
                    params,
                )
                row = cursor.fetchone()
            else:
                row = _fetch_project(cursor, project_id)
    return row


@router.get("/{project_id}/knowledge-items", response_model=list[ProjectKnowledgeItemOut])
def list_project_knowledge_items(
    project_id: str,
    item_kind: str | None = None,
    q: str | None = Query(default=None, min_length=1, max_length=120),
    limit: int = Query(default=50, ge=1, le=200),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute("SELECT project_id FROM projects WHERE project_id = %s", (project_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="Project not found")

            where_clauses = ["project_id = %s"]
            params: list[object] = [project_id]
            if item_kind:
                where_clauses.append("item_kind = %s")
                params.append(item_kind)
            search_query = q.strip() if q else ""
            if search_query:
                search_token = f"%{search_query}%"
                where_clauses.append(
                    """
                    (
                        title ILIKE %s
                        OR content ILIKE %s
                        OR tags::text ILIKE %s
                        OR evidence_refs::text ILIKE %s
                    )
                    """
                )
                params.extend([search_token, search_token, search_token, search_token])
            params.append(limit)
            cursor.execute(
                f"""
                SELECT knowledge_id,
                    project_id,
                    source_meeting_id,
                    source_analysis_id,
                    item_kind,
                    source_item_index,
                    title,
                    content,
                    evidence_refs,
                    tags,
                    status,
                    created_at
                FROM project_knowledge_items
                WHERE {" AND ".join(where_clauses)}
                ORDER BY created_at DESC
                LIMIT %s
                """,
                params,
            )
            return [ProjectKnowledgeItemOut.model_validate(row) for row in cursor.fetchall()]


@router.post("/{project_id}/members", response_model=ProjectMemberOut)
def add_project_member(project_id: str, payload: ProjectMemberAdd):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            _ensure_project_exists(cursor, project_id)
            cursor.execute(
                """
                INSERT INTO project_members
                    (project_id, user_id, project_role, allocation_percent, planned_mm,
                     staffing_note, annual_salary_krw, allocated_cost_krw)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (project_id, user_id)
                DO UPDATE SET
                    project_role = EXCLUDED.project_role,
                    allocation_percent = EXCLUDED.allocation_percent,
                    planned_mm = EXCLUDED.planned_mm,
                    staffing_note = EXCLUDED.staffing_note,
                    annual_salary_krw = EXCLUDED.annual_salary_krw,
                    allocated_cost_krw = EXCLUDED.allocated_cost_krw
                """,
                (
                    project_id,
                    payload.user_id,
                    payload.project_role,
                    payload.allocation_percent,
                    payload.planned_mm,
                    payload.staffing_note,
                    payload.annual_salary_krw,
                    payload.allocated_cost_krw,
                ),
            )
            cursor.execute(
                """
                SELECT pm.project_id,
                    u.user_id,
                    u.employee_no,
                    u.name,
                    u.email,
                    u.role AS user_role,
                    pm.project_role,
                    pm.allocation_percent,
                    pm.planned_mm,
                    pm.staffing_note,
                    pm.annual_salary_krw,
                    pm.allocated_cost_krw
                FROM project_members pm
                JOIN users u ON u.user_id = pm.user_id
                WHERE pm.project_id = %s AND pm.user_id = %s
                """,
                (project_id, payload.user_id),
            )
            row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="User not found")
    return row


@router.get("/{project_id}/members", response_model=list[ProjectMemberOut])
def list_project_members(project_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            _ensure_project_exists(cursor, project_id)
            return _fetch_project_members(cursor, project_id)


@router.delete("/{project_id}/members/{user_id}", status_code=204)
def delete_project_member(project_id: str, user_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            _ensure_project_exists(cursor, project_id)
            cursor.execute(
                """
                DELETE FROM project_members
                WHERE project_id = %s AND user_id = %s
                RETURNING project_id
                """,
                (project_id, user_id),
            )
            deleted = cursor.fetchone()
    if deleted is None:
        raise HTTPException(status_code=404, detail="Project member not found")


@router.get("/{project_id}/detail", response_model=ProjectDetailOut)
def get_project_detail(project_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            project = _fetch_project(cursor, project_id)

            members = _fetch_project_members(cursor, project_id)

            cursor.execute(
                """
                SELECT task_id, project_id, source_meeting_id, source_analysis_id, title,
                    description, assignee, due_date, priority, status, conversion_status
                FROM tasks
                WHERE project_id = %s
                ORDER BY created_at DESC
                """,
                (project_id,),
            )
            tasks = [TaskOut.model_validate(row) for row in cursor.fetchall()]

            cursor.execute(
                """
                SELECT demand_id, project_id, source_meeting_id, source_analysis_id, name,
                    resource_type, quantity, needed_from, needed_to, reason, demand_status
                FROM resource_demands
                WHERE project_id = %s
                ORDER BY created_at DESC
                """,
                (project_id,),
            )
            resource_demands = [ResourceDemandOut.model_validate(row) for row in cursor.fetchall()]

            cursor.execute(
                """
                SELECT knowledge_id,
                    project_id,
                    source_meeting_id,
                    source_analysis_id,
                    item_kind,
                    source_item_index,
                    title,
                    content,
                    evidence_refs,
                    tags,
                    status,
                    created_at
                FROM project_knowledge_items
                WHERE project_id = %s
                ORDER BY created_at DESC
                LIMIT 20
                """,
                (project_id,),
            )
            knowledge_items = [ProjectKnowledgeItemOut.model_validate(row) for row in cursor.fetchall()]

            cursor.execute(
                """
                SELECT
                    (SELECT count(*) FROM tasks WHERE project_id = %s) AS tasks_total,
                    (SELECT count(*) FROM tasks WHERE project_id = %s AND status = 'draft') AS tasks_draft,
                    (SELECT count(*) FROM tasks WHERE project_id = %s AND due_date < CURRENT_DATE AND status NOT IN ('done', 'completed', 'closed', 'rejected')) AS tasks_overdue,
                    (SELECT count(*) FROM meetings WHERE project_id = %s) AS meetings_total,
                    (SELECT count(*) FROM meetings WHERE project_id = %s AND status = 'review_required') AS pending_reviews,
                    (SELECT count(*) FROM resource_demands WHERE project_id = %s AND demand_status = 'candidate') AS resource_demands_candidate,
                    (SELECT count(*) FROM risks WHERE project_id = %s AND status = 'candidate') AS risks_candidate,
                    (SELECT count(*) FROM risks WHERE project_id = %s AND status IN ('candidate', 'open', 'active')) AS risks_unresolved,
                    (SELECT count(*) FROM resource_allocations WHERE project_id = %s AND status = 'conflict') AS resource_conflicts,
                    (
                        SELECT count(*)
                        FROM email_distributions ed
                        JOIN meetings m ON m.meeting_id = ed.meeting_id
                        WHERE m.project_id = %s
                          AND ed.status IN ('failed', 'partial_failed', 'retry_wait')
                    ) AS distribution_failures,
                    (SELECT count(*) FROM project_knowledge_items WHERE project_id = %s AND status = 'active') AS knowledge_items
                """,
                (
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                    project_id,
                ),
            )
            counts = cursor.fetchone()

    dashboard = ProjectDashboardOut(project_id=project_id, **counts)
    return ProjectDetailOut(
        **project,
        members=members,
        tasks=tasks,
        resource_demands=resource_demands,
        knowledge_items=knowledge_items,
        dashboard=dashboard,
    )

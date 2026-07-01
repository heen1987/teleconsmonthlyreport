import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.schemas import DelayedTaskRiskPromotionOut, RiskOut, TaskOut
from app.services.auth_tokens import require_active_user

router = APIRouter(prefix="/tasks", tags=["tasks"], dependencies=[Depends(require_active_user)])

ALLOWED_TASK_STATUSES = {"todo", "in_progress", "on_hold", "done", "completed", "closed", "rejected", "cancelled"}


@router.get("", response_model=list[TaskOut])
def list_tasks(project_id: str | None = None):
    query = """
        SELECT task_id, project_id, source_meeting_id, source_analysis_id, title,
            description, assignee, due_date, priority, status, conversion_status
        FROM tasks
    """
    params: tuple[str, ...] = ()
    if project_id:
        query += " WHERE project_id = %s"
        params = (project_id,)
    query += " ORDER BY created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.patch("/{task_id}/status", response_model=TaskOut)
def update_task_status(
    task_id: str,
    status: str,
    current_user: dict = Depends(require_active_user),
):
    if status not in ALLOWED_TASK_STATUSES:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid status '{status}'. Allowed values: {sorted(ALLOWED_TASK_STATUSES)}",
        )
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                UPDATE tasks
                SET status = %s
                WHERE task_id = %s
                RETURNING task_id, project_id, source_meeting_id, source_analysis_id, title,
                    description, assignee, due_date, priority, status, conversion_status
                """,
                (status, task_id),
            )
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Task not found")
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'update_task_status', 'tasks', %s, %s)
                """,
                (current_user["user_id"], task_id, Jsonb({"status": status})),
            )
    return row


@router.post("/overdue-risks", response_model=DelayedTaskRiskPromotionOut)
def promote_overdue_tasks_to_risks(
    project_id: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    current_user: dict = Depends(require_active_user),
):
    filters = [
        "t.due_date < CURRENT_DATE",
        "t.status NOT IN ('done', 'completed', 'closed', 'rejected')",
    ]
    if project_id:
        filters.append("t.project_id = %s")
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT t.task_id,
                    t.project_id,
                    t.source_meeting_id,
                    t.source_analysis_id,
                    t.title,
                    t.assignee,
                    t.due_date,
                    t.status
                FROM tasks t
                WHERE {" AND ".join(filters)}
                ORDER BY t.due_date ASC, t.created_at ASC
                LIMIT %s
                """,
                ([project_id] if project_id else []) + [limit],
            )
            overdue_tasks = cursor.fetchall()

            created_risks: list[RiskOut] = []
            for task in overdue_tasks:
                task_marker = [{"source_type": "task_delay", "task_id": task["task_id"]}]
                cursor.execute(
                    """
                    SELECT risk_id
                    FROM risks
                    WHERE project_id = %s
                      AND status IN ('candidate', 'open', 'active')
                      AND evidence_refs @> %s
                    LIMIT 1
                    """,
                    (task["project_id"], Jsonb(task_marker)),
                )
                if cursor.fetchone() is not None:
                    continue

                days_late = (date.today() - task["due_date"]).days if task["due_date"] else 0
                level = "high" if days_late >= 7 else "medium"
                assignee_text = f" assignee={task['assignee']}" if task["assignee"] else ""
                evidence = (
                    f"Task {task['task_id']} is {days_late} day(s) overdue"
                    f" with status={task['status']}.{assignee_text}"
                )
                evidence_refs = task_marker + [
                    {
                        "due_date": task["due_date"].isoformat() if task["due_date"] else None,
                        "status": task["status"],
                        "days_late": days_late,
                    }
                ]
                cursor.execute(
                    """
                    INSERT INTO risks
                        (
                            risk_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            title,
                            level,
                            evidence,
                            evidence_refs,
                            ai_confidence,
                            status
                        )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NULL, 'candidate')
                    RETURNING risk_id,
                        project_id,
                        source_meeting_id,
                        source_analysis_id,
                        title,
                        level,
                        evidence,
                        evidence_refs,
                        ai_confidence,
                        status
                    """,
                    (
                        f"RSK-{uuid.uuid4().hex[:12]}",
                        task["project_id"],
                        task["source_meeting_id"],
                        task["source_analysis_id"],
                        f"Delayed task: {task['title']}",
                        level,
                        evidence,
                        Jsonb(evidence_refs),
                    ),
                )
                risk = cursor.fetchone()
                created_risks.append(RiskOut.model_validate(risk))
                cursor.execute(
                    """
                    INSERT INTO audit_logs
                        (actor_user_id, action_type, target_table, target_id, after_value)
                    VALUES (%s, 'promote_overdue_task_to_risk', 'risks', %s, %s)
                    """,
                    (
                        current_user["user_id"],
                        risk["risk_id"],
                        Jsonb(
                            {
                                "source_type": "task_delay",
                                "task_id": task["task_id"],
                                "days_late": days_late,
                                "risk_level": level,
                            }
                        ),
                    ),
                )

    return DelayedTaskRiskPromotionOut(
        scanned_overdue_tasks=len(overdue_tasks),
        created_risks=created_risks,
    )

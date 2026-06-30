import uuid

from fastapi import APIRouter, Depends, HTTPException
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import MeetingStatus, MinutesStatus
from app.services.auth_tokens import require_active_user
from app.services.knowledge_index import index_approved_meeting_analysis

router = APIRouter(prefix="/approvals", tags=["approvals"])


@router.post("/meeting-analyses/{analysis_id}/approve")
def approve_meeting_analysis(
    analysis_id: str,
    current_user: dict = Depends(require_active_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT ma.meeting_id, m.project_id, ma.result_json
                FROM meeting_analyses ma
                JOIN meetings m ON m.meeting_id = ma.meeting_id
                WHERE ma.analysis_id = %s AND ma.status = 'draft'
                """,
                (analysis_id,),
            )
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Draft analysis not found")

            result = row["result_json"]
            project_id = row["project_id"]
            meeting_id = row["meeting_id"]
            created_task_count = 0
            created_decision_count = 0
            created_resource_demand_count = 0
            created_risk_count = 0
            created_knowledge_count = 0

            for item_index, item in enumerate(result.get("action_items", []), start=1):
                if item.get("target_module", "task") != "task":
                    continue
                if item.get("task_conversion_status") == "rejected":
                    continue
                cursor.execute(
                    """
                    INSERT INTO tasks
                        (
                            task_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            source_action_item_index,
                            title,
                            description,
                            assignee,
                            due_date,
                            priority,
                            ai_confidence,
                            evidence_refs,
                            conversion_policy,
                            conversion_status
                        )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        f"TSK-{uuid.uuid4().hex[:12]}",
                        project_id,
                        meeting_id,
                        analysis_id,
                        item_index,
                        item["title"],
                        item.get("evidence"),
                        item.get("assignee"),
                        item.get("due_date"),
                        item.get("priority", "medium"),
                        item.get("confidence"),
                        Jsonb(item.get("evidence_refs", [])),
                        item.get("task_conversion_policy", "manual_review_required"),
                        "draft",
                    ),
                )
                created_task_count += 1

            for decision in result.get("decisions", []):
                cursor.execute(
                    """
                    INSERT INTO project_decisions
                        (decision_id, project_id, source_meeting_id, content)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (
                        f"DEC-{uuid.uuid4().hex[:12]}",
                        project_id,
                        meeting_id,
                        decision["content"],
                    ),
                )
                created_decision_count += 1

            for resource_index, resource in enumerate(result.get("required_resources", []), start=1):
                cursor.execute(
                    """
                    INSERT INTO resource_demands
                        (
                            demand_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            source_required_resource_index,
                            name,
                            resource_type,
                            quantity,
                            needed_from,
                            needed_to,
                            reason,
                            evidence,
                            evidence_refs,
                            ai_confidence,
                            demand_status,
                            conversion_policy
                        )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        f"RDM-{uuid.uuid4().hex[:12]}",
                        project_id,
                        meeting_id,
                        analysis_id,
                        resource_index,
                        resource["name"],
                        resource.get("resource_type", "other"),
                        resource.get("quantity"),
                        resource.get("needed_from"),
                        resource.get("needed_to"),
                        resource.get("reason"),
                        resource.get("evidence"),
                        Jsonb(resource.get("evidence_refs", [])),
                        resource.get("confidence"),
                        "candidate",
                        "manual_review_required",
                    ),
                )
                created_resource_demand_count += 1

            for risk in result.get("risks", []):
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
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        f"RSK-{uuid.uuid4().hex[:12]}",
                        project_id,
                        meeting_id,
                        analysis_id,
                        risk["title"],
                        risk.get("level", "medium"),
                        risk.get("evidence"),
                        Jsonb(risk.get("evidence_refs", [])),
                        risk.get("confidence"),
                        "candidate",
                    ),
                )
                created_risk_count += 1

            created_knowledge_count = index_approved_meeting_analysis(
                cursor,
                project_id=project_id,
                meeting_id=meeting_id,
                analysis_id=analysis_id,
                result=result,
            )

            cursor.execute(
                """
                UPDATE meeting_analyses
                SET status = %s, approved_at = now()
                WHERE analysis_id = %s
                """,
                (MinutesStatus.APPROVED.value, analysis_id),
            )
            cursor.execute(
                """
                UPDATE meetings
                SET status = %s
                WHERE meeting_id = %s
                """,
                (MeetingStatus.APPROVED.value, meeting_id),
            )
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'approve_meeting_analysis', 'meeting_analyses', %s, %s)
                """,
                (
                    current_user["user_id"],
                    analysis_id,
                    Jsonb(
                        {
                            "status": "approved",
                            "created_tasks": created_task_count,
                            "created_decisions": created_decision_count,
                            "created_resource_demands": created_resource_demand_count,
                            "created_risks": created_risk_count,
                            "created_knowledge_items": created_knowledge_count,
                        }
                    ),
                ),
            )

    return {
        "analysis_id": analysis_id,
        "status": "approved",
        "created_tasks": created_task_count,
        "created_decisions": created_decision_count,
        "created_resource_demands": created_resource_demand_count,
        "created_risks": created_risk_count,
        "created_knowledge_items": created_knowledge_count,
    }

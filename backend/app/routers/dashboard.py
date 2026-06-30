from fastapi import APIRouter, Depends
from psycopg.rows import dict_row

from app.db.session import get_connection
from app.schemas import DashboardSummaryOut
from app.services.auth_tokens import require_active_user

router = APIRouter(prefix="/dashboard", tags=["dashboard"], dependencies=[Depends(require_active_user)])


@router.get("/summary", response_model=DashboardSummaryOut)
def get_dashboard_summary():
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT
                    (SELECT count(*) FROM projects) AS projects,
                    (SELECT count(*) FROM meetings) AS meetings,
                    (SELECT count(*) FROM meetings WHERE status = 'review_required') AS pending_reviews,
                    (SELECT count(*) FROM tasks WHERE status = 'draft') AS draft_tasks,
                    (SELECT count(*) FROM tasks WHERE due_date < CURRENT_DATE AND status NOT IN ('done', 'completed', 'closed', 'rejected')) AS overdue_tasks,
                    (SELECT count(*) FROM resource_demands WHERE demand_status = 'candidate') AS resource_demands,
                    (SELECT count(*) FROM resource_usage_entries) AS resource_usage_entries,
                    (SELECT count(*) FROM project_cost_candidates WHERE status = 'candidate') AS cost_candidates,
                    (SELECT count(*) FROM risks WHERE status = 'candidate') AS candidate_risks,
                    (SELECT count(*) FROM risks WHERE status IN ('candidate', 'open', 'active')) AS unresolved_risks,
                    (SELECT count(*) FROM resource_allocations WHERE status = 'conflict') AS resource_conflicts,
                    (SELECT count(*) FROM email_distributions WHERE status IN ('failed', 'partial_failed', 'retry_wait')) AS distribution_failures,
                    (SELECT count(*) FROM project_knowledge_items WHERE status = 'active') AS knowledge_items
                """
            )
            row = cursor.fetchone()
    return row

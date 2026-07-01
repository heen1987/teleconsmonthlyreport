from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import MeetingStatus, MinutesStatus
from app.schemas import (
    MeetingAnalyzeRequest,
    MeetingAnalysisOut,
    MeetingAnalysisReviewEditRequest,
    MeetingAnalysisResult,
    MeetingAttendeeOut,
    MeetingAttendeesReplaceRequest,
    MeetingCreate,
    MeetingListItemOut,
    MeetingOut,
    MeetingReviewPackage,
    MeetingStatusOut,
    ReviewCapabilities,
    ReviewCounts,
)
from app.services.collection_client import (
    CollectionJobError,
    create_transcript_analysis_job,
    wait_for_analysis_job,
)
from app.services.meeting_analysis_store import store_draft_meeting_analysis
from app.services.auth_tokens import require_active_user
from app.services.project_access import append_project_access_filter, ensure_project_access

router = APIRouter(prefix="/meetings", tags=["meetings"], dependencies=[Depends(require_active_user)])

MEETING_STATUS_PROGRESS = {
    MeetingStatus.CREATED.value: 5,
    MeetingStatus.UPLOAD_REQUESTED.value: 10,
    MeetingStatus.UPLOADED.value: 25,
    MeetingStatus.ANALYSIS_QUEUED.value: 40,
    MeetingStatus.ANALYZING.value: 55,
    MeetingStatus.REVIEW_REQUIRED.value: 75,
    MeetingStatus.APPROVED.value: 90,
    MeetingStatus.DISTRIBUTED.value: 100,
    MeetingStatus.UPLOAD_FAILED.value: 100,
    MeetingStatus.ANALYSIS_FAILED.value: 100,
    MeetingStatus.REVIEW_REJECTED.value: 100,
    MeetingStatus.DISTRIBUTION_FAILED.value: 95,
}

MEETING_STATUS_ERROR_CODES = {
    MeetingStatus.UPLOAD_FAILED.value: "UPLOAD_FAILED",
    MeetingStatus.ANALYSIS_FAILED.value: "ANALYSIS_FAILED",
    MeetingStatus.REVIEW_REJECTED.value: "REVIEW_REJECTED",
    MeetingStatus.DISTRIBUTION_FAILED.value: "DISTRIBUTION_FAILED",
}


def _review_package_from_rows(meeting: dict, analysis_row: dict) -> MeetingReviewPackage:
    result = MeetingAnalysisResult.model_validate(analysis_row["result_json"])
    analysis_status = analysis_row["status"]
    meeting_status = meeting["status"]

    counts = ReviewCounts(
        transcript_segments=len(result.transcript_segments),
        decisions=len(result.decisions),
        action_items=len(result.action_items),
        risks=len(result.risks),
        required_resources=len(result.required_resources),
    )
    is_draft = analysis_status in {
        MinutesStatus.DRAFT.value,
        MinutesStatus.REVIEW_REQUIRED.value,
    }
    is_meeting_reviewable = meeting_status == MeetingStatus.REVIEW_REQUIRED.value
    capabilities = ReviewCapabilities(
        can_edit=is_draft,
        can_approve=is_draft and is_meeting_reviewable,
        can_reject=is_draft and is_meeting_reviewable,
        can_distribute=analysis_status == MinutesStatus.APPROVED.value
        and meeting_status == MeetingStatus.APPROVED.value,
    )

    warnings: list[str] = []
    if not result.requires_human_approval:
        warnings.append("analysis_result_requires_human_approval_missing")
    if counts.transcript_segments == 0:
        warnings.append("transcript_segments_empty")
    if analysis_status == MinutesStatus.APPROVED.value and meeting_status not in {
        MeetingStatus.APPROVED.value,
        MeetingStatus.DISTRIBUTED.value,
    }:
        warnings.append("approved_analysis_meeting_status_mismatch")

    return MeetingReviewPackage(
        meeting=MeetingOut.model_validate(meeting),
        analysis_id=analysis_row["analysis_id"],
        analysis_status=analysis_status,
        model_name=analysis_row["model_name"],
        result=result,
        counts=counts,
        capabilities=capabilities,
        warnings=warnings,
    )


def _list_attendees(cursor, meeting_id: str) -> list[MeetingAttendeeOut]:
    cursor.execute(
        """
        SELECT ma.meeting_id, u.user_id, u.employee_no, u.name, pm.project_role
        FROM meeting_attendees ma
        JOIN meetings m ON m.meeting_id = ma.meeting_id
        JOIN users u ON u.user_id = ma.user_id
        JOIN project_members pm ON pm.project_id = m.project_id AND pm.user_id = ma.user_id
        WHERE ma.meeting_id = %s
        ORDER BY ma.created_at ASC
        """,
        (meeting_id,),
    )
    return [MeetingAttendeeOut.model_validate(row) for row in cursor.fetchall()]


@router.put("/analyses/{analysis_id}/review-edits", response_model=MeetingReviewPackage)
def update_review_edits(
    analysis_id: str,
    payload: MeetingAnalysisReviewEditRequest,
    current_user: dict = Depends(require_active_user),
):
    result_json = payload.result.model_dump(mode="json")
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT ma.analysis_id, ma.status, ma.result_json, ma.meeting_id,
                    m.project_id, m.status AS meeting_status
                FROM meeting_analyses ma
                JOIN meetings m ON m.meeting_id = ma.meeting_id
                WHERE ma.analysis_id = %s
                FOR UPDATE
                """,
                (analysis_id,),
            )
            current = cursor.fetchone()
            if current is None:
                raise HTTPException(status_code=404, detail="Meeting analysis not found")
            ensure_project_access(cursor, current["project_id"], current_user)
            if current["status"] not in {MinutesStatus.DRAFT.value, MinutesStatus.REVIEW_REQUIRED.value}:
                raise HTTPException(status_code=409, detail="Only draft analyses can be edited")
            if current["meeting_status"] != MeetingStatus.REVIEW_REQUIRED.value:
                raise HTTPException(status_code=409, detail="Meeting is not in review_required status")

            cursor.execute(
                """
                UPDATE meeting_analyses
                SET result_json = %s,
                    summary = %s,
                    status = %s
                WHERE analysis_id = %s
                """,
                (
                    Jsonb(result_json),
                    payload.result.summary,
                    MinutesStatus.DRAFT.value,
                    analysis_id,
                ),
            )
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'edit_meeting_analysis_draft', 'meeting_analyses', %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    analysis_id,
                    Jsonb(
                        {
                            "status": current["status"],
                            "summary": current["result_json"].get("summary"),
                            "counts": {
                                "decisions": len(current["result_json"].get("decisions", [])),
                                "action_items": len(current["result_json"].get("action_items", [])),
                                "risks": len(current["result_json"].get("risks", [])),
                                "required_resources": len(current["result_json"].get("required_resources", [])),
                            },
                        }
                    ),
                    Jsonb(
                        {
                            "status": MinutesStatus.DRAFT.value,
                            "summary": payload.result.summary,
                            "edit_reason": payload.edit_reason,
                            "counts": {
                                "decisions": len(payload.result.decisions),
                                "action_items": len(payload.result.action_items),
                                "risks": len(payload.result.risks),
                                "required_resources": len(payload.result.required_resources),
                            },
                        }
                    ),
                ),
            )
            return _load_review_package_by_analysis_id(cursor, analysis_id)


def _load_review_package_by_analysis_id(cursor, analysis_id: str) -> MeetingReviewPackage:
    cursor.execute(
        """
        SELECT ma.analysis_id, ma.status, ma.model_name, ma.result_json,
            m.meeting_id, m.project_id, m.title, m.created_by, m.status AS meeting_status,
            m.audio_path, m.transcript
        FROM meeting_analyses ma
        JOIN meetings m ON m.meeting_id = ma.meeting_id
        WHERE ma.analysis_id = %s
        """,
        (analysis_id,),
    )
    row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Meeting analysis not found")
    meeting = {
        "meeting_id": row["meeting_id"],
        "project_id": row["project_id"],
        "title": row["title"],
        "created_by": row["created_by"],
        "status": row["meeting_status"],
        "audio_path": row["audio_path"],
        "transcript": row["transcript"],
    }
    analysis_row = {
        "analysis_id": row["analysis_id"],
        "status": row["status"],
        "model_name": row["model_name"],
        "result_json": row["result_json"],
    }
    return _review_package_from_rows(meeting, analysis_row)


@router.post("", response_model=MeetingOut)
def create_meeting(payload: MeetingCreate, current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            ensure_project_access(cursor, payload.project_id, current_user)
            cursor.execute(
                """
                INSERT INTO meetings (meeting_id, project_id, title, created_by)
                VALUES (%s, %s, %s, %s)
                RETURNING meeting_id, project_id, title, created_by, status, audio_path, transcript
                """,
                (payload.meeting_id, payload.project_id, payload.title, current_user["user_id"]),
            )
            row = cursor.fetchone()
    return row


@router.get("", response_model=list[MeetingListItemOut])
def list_meetings(
    project_id: str | None = None,
    status: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    current_user: dict = Depends(require_active_user),
):
    filters: list[str] = []
    params: list[object] = []
    if project_id:
        filters.append("m.project_id = %s")
        params.append(project_id)
    if status:
        filters.append("m.status = %s")
        params.append(status)
    append_project_access_filter(filters, params, current_user, "p")
    where_clause = f"WHERE {' AND '.join(filters)}" if filters else ""

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT
                    m.meeting_id,
                    m.project_id,
                    p.name AS project_name,
                    m.title,
                    m.status,
                    m.created_by,
                    m.created_at,
                    latest.analysis_id AS latest_analysis_id,
                    latest.status AS latest_analysis_status,
                    latest.model_name AS latest_model_name
                FROM meetings m
                JOIN projects p ON p.project_id = m.project_id
                LEFT JOIN LATERAL (
                    SELECT analysis_id, status, model_name
                    FROM meeting_analyses
                    WHERE meeting_id = m.meeting_id
                    ORDER BY
                        CASE WHEN model_name LIKE 'aggregate:%%' THEN 0 ELSE 1 END,
                        created_at DESC
                    LIMIT 1
                ) latest ON true
                {where_clause}
                ORDER BY m.created_at DESC
                LIMIT %s
                """,
                (*params, limit),
            )
            rows = cursor.fetchall()
    return rows


@router.get("/{meeting_id}/status", response_model=MeetingStatusOut)
def get_meeting_status(meeting_id: str, current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT
                    m.meeting_id,
                    m.project_id,
                    p.name AS project_name,
                    m.title,
                    m.status,
                    m.created_at,
                    latest_analysis.analysis_id AS latest_analysis_id,
                    latest_analysis.status AS latest_analysis_status,
                    latest_analysis.model_name AS latest_model_name,
                    latest_distribution.distribution_id AS latest_distribution_id,
                    latest_distribution.status AS latest_distribution_status
                FROM meetings m
                JOIN projects p ON p.project_id = m.project_id
                LEFT JOIN LATERAL (
                    SELECT analysis_id, status, model_name
                    FROM meeting_analyses
                    WHERE meeting_id = m.meeting_id
                    ORDER BY
                        CASE WHEN model_name LIKE 'aggregate:%%' THEN 0 ELSE 1 END,
                        created_at DESC
                    LIMIT 1
                ) latest_analysis ON true
                LEFT JOIN LATERAL (
                    SELECT distribution_id, status
                    FROM email_distributions
                    WHERE meeting_id = m.meeting_id
                    ORDER BY created_at DESC
                    LIMIT 1
                ) latest_distribution ON true
                WHERE m.meeting_id = %s
                """,
                (meeting_id,),
            )
            row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Meeting not found")
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            ensure_project_access(cursor, row["project_id"], current_user)
    return MeetingStatusOut(
        **row,
        progress=MEETING_STATUS_PROGRESS.get(row["status"], 0),
        error_code=MEETING_STATUS_ERROR_CODES.get(row["status"]),
    )


@router.get("/{meeting_id}", response_model=MeetingOut)
def get_meeting(meeting_id: str, current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT meeting_id, project_id, title, created_by, status, audio_path, transcript
                FROM meetings
                WHERE meeting_id = %s
                """,
                (meeting_id,),
            )
            row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Meeting not found")
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            ensure_project_access(cursor, row["project_id"], current_user)
    return row


@router.get("/{meeting_id}/attendees", response_model=list[MeetingAttendeeOut])
def list_meeting_attendees(meeting_id: str, current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                "SELECT meeting_id, project_id FROM meetings WHERE meeting_id = %s",
                (meeting_id,),
            )
            meeting = cursor.fetchone()
            if meeting is None:
                raise HTTPException(status_code=404, detail="Meeting not found")
            ensure_project_access(cursor, meeting["project_id"], current_user)
            return _list_attendees(cursor, meeting_id)


@router.put("/{meeting_id}/attendees", response_model=list[MeetingAttendeeOut])
def replace_meeting_attendees(
    meeting_id: str,
    payload: MeetingAttendeesReplaceRequest,
    current_user: dict = Depends(require_active_user),
):
    attendee_user_ids = list(dict.fromkeys(payload.attendee_user_ids))
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                "SELECT meeting_id, project_id FROM meetings WHERE meeting_id = %s",
                (meeting_id,),
            )
            meeting = cursor.fetchone()
            if meeting is None:
                raise HTTPException(status_code=404, detail="Meeting not found")
            ensure_project_access(cursor, meeting["project_id"], current_user)

            before_attendees = [row.model_dump(mode="json") for row in _list_attendees(cursor, meeting_id)]

            if attendee_user_ids:
                cursor.execute(
                    """
                    SELECT user_id
                    FROM project_members
                    WHERE project_id = %s AND user_id = ANY(%s)
                    """,
                    (meeting["project_id"], attendee_user_ids),
                )
                valid_ids = {row["user_id"] for row in cursor.fetchall()}
                invalid_ids = [user_id for user_id in attendee_user_ids if user_id not in valid_ids]
                if invalid_ids:
                    raise HTTPException(
                        status_code=409,
                        detail={
                            "message": "Attendee must be a project member",
                            "invalid_user_ids": invalid_ids,
                        },
                    )

            cursor.execute("DELETE FROM meeting_attendees WHERE meeting_id = %s", (meeting_id,))
            for user_id in attendee_user_ids:
                cursor.execute(
                    """
                    INSERT INTO meeting_attendees (meeting_id, user_id)
                    VALUES (%s, %s)
                    ON CONFLICT (meeting_id, user_id) DO NOTHING
                    """,
                    (meeting_id, user_id),
                )

            after_attendees = [row.model_dump(mode="json") for row in _list_attendees(cursor, meeting_id)]
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    "meeting_attendees_replace",
                    "meeting_attendees",
                    meeting_id,
                    Jsonb(before_attendees),
                    Jsonb(after_attendees),
                ),
            )
            return _list_attendees(cursor, meeting_id)


@router.get("/{meeting_id}/review-package", response_model=MeetingReviewPackage)
def get_review_package(meeting_id: str, current_user: dict = Depends(require_active_user)):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT meeting_id, project_id, title, created_by, status, audio_path, transcript
                FROM meetings
                WHERE meeting_id = %s
                """,
                (meeting_id,),
            )
            meeting = cursor.fetchone()
            if meeting is None:
                raise HTTPException(status_code=404, detail="Meeting not found")
            ensure_project_access(cursor, meeting["project_id"], current_user)

            cursor.execute(
                """
                SELECT analysis_id, status, model_name, result_json
                FROM meeting_analyses
                WHERE meeting_id = %s
                ORDER BY
                    CASE WHEN model_name LIKE 'aggregate:%%' THEN 0 ELSE 1 END,
                    created_at DESC
                LIMIT 1
                """,
                (meeting_id,),
            )
            analysis_row = cursor.fetchone()
            if analysis_row is None:
                raise HTTPException(status_code=404, detail="Meeting analysis not found")

    return _review_package_from_rows(meeting, analysis_row)


@router.post("/analyze", response_model=MeetingAnalysisOut)
async def analyze_meeting(
    payload: MeetingAnalyzeRequest,
    current_user: dict = Depends(require_active_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT meeting_id, project_id
                FROM meetings
                WHERE meeting_id = %s
                """,
                (payload.meeting_id,),
            )
            meeting = cursor.fetchone()
            if meeting is None:
                raise HTTPException(status_code=404, detail="Meeting not found")
            ensure_project_access(cursor, meeting["project_id"], current_user)
            cursor.execute(
                """
                UPDATE meetings
                SET transcript = %s, status = %s
                WHERE meeting_id = %s
                """,
                (payload.transcript, MeetingStatus.ANALYSIS_QUEUED.value, payload.meeting_id),
            )

    try:
        collection_job_id = await create_transcript_analysis_job(
            project_id=meeting["project_id"],
            meeting_id=payload.meeting_id,
            transcript=payload.transcript,
            requested_by=current_user["user_id"],
        )
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE meetings
                    SET status = %s
                    WHERE meeting_id = %s
                    """,
                    (MeetingStatus.ANALYZING.value, payload.meeting_id),
                )
        model_name, analysis = await wait_for_analysis_job(collection_job_id)
    except (CollectionJobError, Exception) as exc:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE meetings
                    SET status = %s
                    WHERE meeting_id = %s
                    """,
                    (MeetingStatus.ANALYSIS_FAILED.value, payload.meeting_id),
                )
        raise HTTPException(
            status_code=503,
            detail=f"Collection analysis job failed: {exc}",
        ) from exc

    analysis_id, _created, _analysis_status = store_draft_meeting_analysis(
        meeting_id=payload.meeting_id,
        project_id=meeting["project_id"],
        model_name=model_name,
        result=analysis,
        source_collection_job_id=collection_job_id,
        transcript=payload.transcript,
    )

    return MeetingAnalysisOut(
        analysis_id=analysis_id,
        meeting_id=payload.meeting_id,
        status=_analysis_status,
        model_name=model_name,
        result=analysis,
    )

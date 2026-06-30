from __future__ import annotations

import uuid

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import MeetingStatus
from app.schemas import MeetingAnalysisResult


class MeetingAnalysisStoreError(RuntimeError):
    pass


class MeetingAnalysisProjectMismatchError(MeetingAnalysisStoreError):
    pass


class MeetingAnalysisConflictError(MeetingAnalysisStoreError):
    pass


def store_draft_meeting_analysis(
    *,
    meeting_id: str,
    project_id: str | None = None,
    model_name: str,
    result: MeetingAnalysisResult,
    source_collection_job_id: str | None = None,
    source_asset_id: str | None = None,
    audio_path: str | None = None,
    transcript: str | None = None,
) -> tuple[str, bool, str]:
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT meeting_id, project_id
                FROM meetings
                WHERE meeting_id = %s
                FOR UPDATE
                """,
                (meeting_id,),
            )
            meeting = cursor.fetchone()
            if meeting is None:
                raise MeetingAnalysisStoreError(f"Meeting not found: {meeting_id}")
            if project_id is not None and meeting["project_id"] != project_id:
                raise MeetingAnalysisProjectMismatchError(
                    f"Meeting {meeting_id} belongs to project {meeting['project_id']}, not {project_id}"
                )

            analysis_id = f"ANL-{uuid.uuid4().hex[:12]}"
            if source_collection_job_id:
                cursor.execute(
                    """
                    INSERT INTO meeting_analyses
                        (
                            analysis_id,
                            meeting_id,
                            source_collection_job_id,
                            source_asset_id,
                            model_name,
                            summary,
                            result_json
                        )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (source_collection_job_id)
                    WHERE source_collection_job_id IS NOT NULL
                    DO NOTHING
                    RETURNING analysis_id, status
                    """,
                    (
                        analysis_id,
                        meeting_id,
                        source_collection_job_id,
                        source_asset_id,
                        model_name,
                        result.summary,
                        Jsonb(result.model_dump(mode="json")),
                    ),
                )
                inserted = cursor.fetchone()
                if inserted is None:
                    cursor.execute(
                        """
                        SELECT analysis_id, meeting_id, status
                        FROM meeting_analyses
                        WHERE source_collection_job_id = %s
                        """,
                        (source_collection_job_id,),
                    )
                    existing = cursor.fetchone()
                    if existing is None:
                        raise MeetingAnalysisConflictError(
                            f"Analysis conflict was detected but not found: {source_collection_job_id}"
                        )
                    if existing["meeting_id"] != meeting_id:
                        raise MeetingAnalysisConflictError(
                            f"Collection job {source_collection_job_id} is already linked to meeting "
                            f"{existing['meeting_id']}"
                        )
                    return existing["analysis_id"], False, existing["status"]
                analysis_id = inserted["analysis_id"]
            else:
                cursor.execute(
                    """
                    INSERT INTO meeting_analyses
                        (
                            analysis_id,
                            meeting_id,
                            source_collection_job_id,
                            source_asset_id,
                            model_name,
                            summary,
                            result_json
                        )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING analysis_id, status
                    """,
                    (
                        analysis_id,
                        meeting_id,
                        source_collection_job_id,
                        source_asset_id,
                        model_name,
                        result.summary,
                        Jsonb(result.model_dump(mode="json")),
                    ),
                )
                inserted = cursor.fetchone()
                analysis_id = inserted["analysis_id"]
            cursor.execute(
                """
                UPDATE meetings
                SET status = %s,
                    audio_path = COALESCE(%s, audio_path),
                    transcript = COALESCE(%s, transcript)
                WHERE meeting_id = %s
                """,
                (
                    MeetingStatus.REVIEW_REQUIRED.value,
                    audio_path,
                    transcript,
                    meeting_id,
                ),
            )
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    "system",
                    "store_meeting_analysis_draft",
                    "meeting_analyses",
                    analysis_id,
                    Jsonb(
                        {
                            "meeting_id": meeting_id,
                            "source_collection_job_id": source_collection_job_id,
                            "source_asset_id": source_asset_id,
                            "status": "draft",
                        }
                    ),
                ),
            )

    return analysis_id, True, "draft"

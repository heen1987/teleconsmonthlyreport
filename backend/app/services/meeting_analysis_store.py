from __future__ import annotations

import uuid

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.domain.statuses import MeetingStatus
from app.schemas import MeetingAnalysisResult

AGGREGATE_MODEL_PREFIX = "aggregate:"


class MeetingAnalysisStoreError(RuntimeError):
    pass


class MeetingAnalysisProjectMismatchError(MeetingAnalysisStoreError):
    pass


class MeetingAnalysisConflictError(MeetingAnalysisStoreError):
    pass


def _merge_raw_analysis_results(rows: list[dict]) -> MeetingAnalysisResult:
    summaries: list[str] = []
    transcript_segments = []
    decisions = []
    action_items = []
    risks = []
    required_resources = []
    language = "ko"

    for index, row in enumerate(rows, start=1):
        result = MeetingAnalysisResult.model_validate(row["result_json"])
        language = result.language or language
        summaries.append(f"[segment {index}] {result.summary}")
        source_key = row.get("source_collection_job_id") or row["analysis_id"]
        for segment in result.transcript_segments:
            transcript_segments.append(
                segment.model_copy(
                    update={"segment_id": f"{index}:{source_key}:{segment.segment_id}"}
                )
            )
        decisions.extend(result.decisions)
        action_items.extend(result.action_items)
        risks.extend(result.risks)
        required_resources.extend(result.required_resources)

    return MeetingAnalysisResult(
        schema_version="analysis.v1",
        language=language,
        summary="\n".join(summaries),
        transcript_segments=transcript_segments,
        decisions=decisions,
        action_items=action_items,
        risks=risks,
        required_resources=required_resources,
        requires_human_approval=True,
    )


def _upsert_meeting_aggregate_analysis(cursor, meeting_id: str) -> tuple[str, bool, str] | None:
    cursor.execute(
        """
        SELECT analysis_id, source_collection_job_id, model_name, result_json
        FROM meeting_analyses
        WHERE meeting_id = %s
          AND status IN (%s, %s)
          AND model_name NOT LIKE %s
        ORDER BY created_at ASC
        """,
        (
            meeting_id,
            "draft",
            "review_required",
            f"{AGGREGATE_MODEL_PREFIX}%",
        ),
    )
    raw_rows = cursor.fetchall()
    if len(raw_rows) <= 1:
        return None

    merged = _merge_raw_analysis_results(raw_rows)
    model_name = f"{AGGREGATE_MODEL_PREFIX}segments"
    cursor.execute(
        """
        SELECT analysis_id
        FROM meeting_analyses
        WHERE meeting_id = %s
          AND status IN (%s, %s)
          AND model_name LIKE %s
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE
        """,
        (
            meeting_id,
            "draft",
            "review_required",
            f"{AGGREGATE_MODEL_PREFIX}%",
        ),
    )
    existing = cursor.fetchone()
    if existing:
        cursor.execute(
            """
            UPDATE meeting_analyses
            SET model_name = %s,
                summary = %s,
                result_json = %s,
                status = %s,
                created_at = now()
            WHERE analysis_id = %s
            RETURNING analysis_id, status
            """,
            (
                model_name,
                merged.summary,
                Jsonb(merged.model_dump(mode="json")),
                "draft",
                existing["analysis_id"],
            ),
        )
        updated = cursor.fetchone()
        return updated["analysis_id"], False, updated["status"]

    aggregate_id = f"ANL-{uuid.uuid4().hex[:12]}"
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
        VALUES (%s, %s, NULL, NULL, %s, %s, %s)
        RETURNING analysis_id, status
        """,
        (
            aggregate_id,
            meeting_id,
            model_name,
            merged.summary,
            Jsonb(merged.model_dump(mode="json")),
        ),
    )
    inserted = cursor.fetchone()
    return inserted["analysis_id"], True, inserted["status"]


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
            aggregate = _upsert_meeting_aggregate_analysis(cursor, meeting_id)
            if aggregate is not None:
                analysis_id, _aggregate_created, analysis_status = aggregate
            else:
                analysis_status = "draft"

    return analysis_id, True, analysis_status

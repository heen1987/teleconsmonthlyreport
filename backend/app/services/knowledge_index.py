from __future__ import annotations

import uuid
from typing import Any

from psycopg.types.json import Jsonb


def _text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _title(value: str, fallback: str) -> str:
    text = _text(value)
    if not text:
        return fallback
    return text[:120]


def _insert_item(
    cursor: Any,
    *,
    project_id: str,
    meeting_id: str,
    analysis_id: str,
    item_kind: str,
    source_item_index: int,
    title: str,
    content: str,
    evidence_refs: list[dict[str, Any]],
    tags: list[str],
) -> bool:
    cursor.execute(
        """
        INSERT INTO project_knowledge_items
            (
                knowledge_id,
                project_id,
                source_meeting_id,
                source_analysis_id,
                item_kind,
                source_item_index,
                title,
                content,
                evidence_refs,
                tags
            )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (source_analysis_id, item_kind, source_item_index)
        DO NOTHING
        RETURNING knowledge_id
        """,
        (
            f"KNO-{uuid.uuid4().hex[:12]}",
            project_id,
            meeting_id,
            analysis_id,
            item_kind,
            source_item_index,
            title,
            content,
            Jsonb(evidence_refs or []),
            Jsonb(tags),
        ),
    )
    return cursor.fetchone() is not None


def index_approved_meeting_analysis(
    cursor: Any,
    *,
    project_id: str,
    meeting_id: str,
    analysis_id: str,
    result: dict[str, Any],
) -> int:
    created_count = 0
    summary = _text(result.get("summary"))
    if summary:
        created_count += int(
            _insert_item(
                cursor,
                project_id=project_id,
                meeting_id=meeting_id,
                analysis_id=analysis_id,
                item_kind="summary",
                source_item_index=0,
                title=_title(summary, "Meeting summary"),
                content=summary,
                evidence_refs=[],
                tags=["meeting", "summary"],
            )
        )

    for index, decision in enumerate(result.get("decisions", []), start=1):
        content = _text(decision.get("content"))
        if not content:
            continue
        created_count += int(
            _insert_item(
                cursor,
                project_id=project_id,
                meeting_id=meeting_id,
                analysis_id=analysis_id,
                item_kind="decision",
                source_item_index=index,
                title=_title(content, f"Decision {index}"),
                content=content,
                evidence_refs=decision.get("evidence_refs", []),
                tags=["meeting", "decision"],
            )
        )

    for index, action_item in enumerate(result.get("action_items", []), start=1):
        if action_item.get("task_conversion_status") == "rejected":
            continue
        title = _text(action_item.get("title"))
        if not title:
            continue
        content_parts = [
            title,
            _text(action_item.get("assignee")),
            _text(action_item.get("due_date")),
            _text(action_item.get("evidence")),
        ]
        created_count += int(
            _insert_item(
                cursor,
                project_id=project_id,
                meeting_id=meeting_id,
                analysis_id=analysis_id,
                item_kind="action_item",
                source_item_index=index,
                title=_title(title, f"Action item {index}"),
                content=" | ".join(part for part in content_parts if part),
                evidence_refs=action_item.get("evidence_refs", []),
                tags=["meeting", "action_item"],
            )
        )

    for index, risk in enumerate(result.get("risks", []), start=1):
        title = _text(risk.get("title"))
        if not title:
            continue
        content = " | ".join(
            part
            for part in [title, _text(risk.get("level")), _text(risk.get("evidence"))]
            if part
        )
        created_count += int(
            _insert_item(
                cursor,
                project_id=project_id,
                meeting_id=meeting_id,
                analysis_id=analysis_id,
                item_kind="risk",
                source_item_index=index,
                title=_title(title, f"Risk {index}"),
                content=content,
                evidence_refs=risk.get("evidence_refs", []),
                tags=["meeting", "risk"],
            )
        )

    for index, resource in enumerate(result.get("required_resources", []), start=1):
        title = _text(resource.get("name"))
        if not title:
            continue
        content_parts = [
            title,
            _text(resource.get("resource_type")),
            _text(resource.get("quantity")),
            _text(resource.get("needed_from")),
            _text(resource.get("needed_to")),
            _text(resource.get("reason")),
            _text(resource.get("evidence")),
        ]
        created_count += int(
            _insert_item(
                cursor,
                project_id=project_id,
                meeting_id=meeting_id,
                analysis_id=analysis_id,
                item_kind="required_resource",
                source_item_index=index,
                title=_title(title, f"Required resource {index}"),
                content=" | ".join(part for part in content_parts if part),
                evidence_refs=resource.get("evidence_refs", []),
                tags=["meeting", "required_resource"],
            )
        )

    return created_count

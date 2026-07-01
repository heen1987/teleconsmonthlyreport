import json
import logging
import re

import httpx

from app.core.config import settings
from app.schemas import (
    ActionItemCandidate,
    DecisionCandidate,
    MeetingAnalysisPayload,
    RequiredResourceCandidate,
    RiskCandidate,
    TranscriptSegment,
)

logger = logging.getLogger(__name__)
FALLBACK_MODEL_NAME = "fallback:rules"


SYSTEM_PROMPT = """You are the local analysis server for a PMS meeting-management module.
Analyze Korean meeting transcripts and return only valid JSON.
Do not infer speakers, assignees, responsibility, or attendance. If the
transcript does not explicitly label a speaker or assignee, return null.
{
  "schema_version": "analysis.v1",
  "language": "ko",
  "summary": "string",
  "transcript_segments": [{
    "segment_id": "string",
    "speaker": "string or null",
    "start_ms": "number or null",
    "end_ms": "number or null",
    "text": "string"
  }],
  "decisions": [{
    "content": "string",
    "evidence": "string or null",
    "evidence_refs": [],
    "confidence": 0.0
  }],
  "action_items": [{
    "title": "string",
    "assignee": "string or null",
    "due_date": "YYYY-MM-DD or null",
    "target_module": "task",
    "evidence": "string or null",
    "evidence_refs": [],
    "priority": "low|medium|high",
    "confidence": 0.0,
    "task_conversion_policy": "manual_review_required",
    "task_conversion_status": "candidate",
    "task_conversion_reason": "string or null"
  }],
  "risks": [{
    "title": "string",
    "level": "low|medium|high",
    "evidence": "string or null",
    "evidence_refs": [],
    "confidence": 0.0
  }],
  "required_resources": [{
    "name": "string",
    "resource_type": "human|equipment|room|vehicle|software|other",
    "quantity": "number or null",
    "needed_from": "YYYY-MM-DD or null",
    "needed_to": "YYYY-MM-DD or null",
    "reason": "string or null",
    "evidence": "string or null",
    "evidence_refs": [],
    "confidence": 0.0
  }],
  "requires_human_approval": true
}
Never approve PMS state, post accounting journals, or create final tasks.
Return draft candidates only.
"""


def _fallback_analysis(transcript: str) -> MeetingAnalysisPayload:
    first_line = (transcript.strip().splitlines() or [""])[0][:160]
    sentences = [
        sentence.strip()
        for sentence in re.split(r"[.!?\n。]+", transcript)
        if sentence.strip()
    ]
    decisions = [
        DecisionCandidate(content=sentence, evidence=sentence)
        for sentence in sentences
        if "결정" in sentence
    ]
    action_items: list[ActionItemCandidate] = []
    for sentence in sentences:
        if "하기로" not in sentence or "결정" in sentence:
            continue
        due_date_match = re.search(r"(20\d{2}-\d{2}-\d{2})", sentence)
        action_items.append(
            ActionItemCandidate(
                title=sentence[:120],
                assignee=None,
                due_date=due_date_match.group(1) if due_date_match else None,
                evidence=sentence,
            )
        )
    risks = [
        RiskCandidate(title=sentence, level="medium", evidence=sentence)
        for sentence in sentences
        if "위험" in sentence or "리스크" in sentence
    ]
    required_resources = [
        RequiredResourceCandidate(name=sentence[:80], resource_type="other", reason=sentence, evidence=sentence)
        for sentence in sentences
        if any(keyword in sentence for keyword in ["장비", "회의실", "차량", "인력", "리소스", "자원"])
    ]
    return MeetingAnalysisPayload(
        schema_version="analysis.v1",
        language="ko",
        summary=f"회의 내용 초안 요약: {first_line}",
        transcript_segments=[
            TranscriptSegment(
                segment_id=f"seg-{index:03d}",
                text=sentence,
            )
            for index, sentence in enumerate(sentences, start=1)
        ],
        decisions=decisions,
        action_items=action_items,
        risks=risks,
        required_resources=required_resources,
        requires_human_approval=True,
    )


def _parse_model_list(value: str) -> list[str]:
    return [model.strip() for model in value.split(",") if model.strip()]


def _model_candidates() -> list[str]:
    configured = [settings.ollama_model, *_parse_model_list(settings.ollama_fallback_models)]
    candidates: list[str] = []
    seen: set[str] = set()
    for model in configured:
        if model and model not in seen:
            candidates.append(model)
            seen.add(model)
    if not any(model.lower().startswith("qwen") for model in candidates):
        candidates.append("qwen3:4b")
    return candidates


def _load_json_payload(content: str) -> dict:
    cleaned = content.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    if not cleaned.startswith("{"):
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if match:
            cleaned = match.group(0)
    return json.loads(cleaned)


def _normalize_candidate_payload(payload: dict) -> dict:
    payload["schema_version"] = payload.get("schema_version") or "analysis.v1"
    payload["language"] = payload.get("language") or "ko"
    payload["requires_human_approval"] = True

    for key in ["transcript_segments", "decisions", "action_items", "risks", "required_resources"]:
        if not isinstance(payload.get(key), list):
            payload[key] = []

    for index, segment in enumerate(payload["transcript_segments"], start=1):
        segment["segment_id"] = segment.get("segment_id") or f"seg-{index:03d}"
        segment["text"] = segment.get("text") or "Transcript segment"

    for decision in payload["decisions"]:
        decision["content"] = decision.get("content") or decision.get("evidence") or "Decision candidate"

    for action_item in payload["action_items"]:
        action_item["title"] = action_item.get("title") or action_item.get("content") or "Action item candidate"
        action_item["target_module"] = action_item.get("target_module") or "task"
        if action_item.get("priority") not in {"low", "medium", "high"}:
            action_item["priority"] = "medium"
        action_item["task_conversion_policy"] = "manual_review_required"
        action_item["task_conversion_status"] = "candidate"

    for risk in payload["risks"]:
        risk["title"] = risk.get("title") or risk.get("content") or "Risk candidate"
        if risk.get("level") not in {"low", "medium", "high"}:
            risk["level"] = "medium"

    for resource in payload["required_resources"]:
        resource["name"] = resource.get("name") or resource.get("reason") or "Required resource candidate"
        if resource.get("resource_type") not in {"human", "equipment", "room", "vehicle", "software", "other"}:
            resource["resource_type"] = "other"

    return payload


def _enforce_draft_safety(result: MeetingAnalysisPayload) -> MeetingAnalysisPayload:
    result.requires_human_approval = True
    for action_item in result.action_items:
        action_item.task_conversion_policy = "manual_review_required"
        action_item.task_conversion_status = "candidate"
    return result


def _build_ollama_payload(model_name: str, transcript: str) -> dict:
    return {
        "model": model_name,
        "stream": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"/no_think\n\nTranscript:\n{transcript}",
            },
        ],
        "options": {
            "temperature": 0.1,
            "num_ctx": settings.default_context_limit,
        },
    }


async def _analyze_with_ollama_model(model_name: str, transcript: str) -> MeetingAnalysisPayload:
    payload = _build_ollama_payload(model_name, transcript)
    async with httpx.AsyncClient(timeout=settings.ollama_timeout_seconds) as client:
        response = await client.post(
            f"{settings.ollama_base_url}/api/chat",
            json=payload,
        )
        response.raise_for_status()
    content = response.json()["message"]["content"]
    normalized_payload = _normalize_candidate_payload(_load_json_payload(content))
    return _enforce_draft_safety(MeetingAnalysisPayload.model_validate(normalized_payload))


async def analyze_transcript(transcript: str) -> tuple[str, MeetingAnalysisPayload]:
    failures: list[str] = []
    for model_name in _model_candidates():
        try:
            return model_name, await _analyze_with_ollama_model(model_name, transcript)
        except Exception as exc:
            failures.append(f"{model_name}: {type(exc).__name__}")
            logger.warning("Meeting analysis failed with model %s: %s", model_name, exc)

    logger.warning("All Ollama model candidates failed; using rule-based fallback: %s", failures)
    return FALLBACK_MODEL_NAME, _fallback_analysis(transcript)

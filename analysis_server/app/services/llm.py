import json
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
    first_line = transcript.strip().splitlines()[0][:160]
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


async def analyze_transcript(transcript: str) -> MeetingAnalysisPayload:
    payload = {
        "model": settings.ollama_model,
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

    try:
        async with httpx.AsyncClient(timeout=90) as client:
            response = await client.post(
                f"{settings.ollama_base_url}/api/chat",
                json=payload,
            )
            response.raise_for_status()
        content = response.json()["message"]["content"]
        return MeetingAnalysisPayload.model_validate(_load_json_payload(content))
    except Exception:
        return _fallback_analysis(transcript)

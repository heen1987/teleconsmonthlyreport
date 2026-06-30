import json

import httpx

from app.core.config import settings
from app.schemas import MeetingAnalysisResult


SYSTEM_PROMPT = """You are an AI assistant inside a PMS meeting-management module.
Do not infer assignees, responsibility, attendance, or speaker identity. If the
transcript does not explicitly label an assignee, return null.
Return only valid JSON matching this shape:
{
  "summary": "string",
  "decisions": [{"content": "string", "evidence": "string or null"}],
  "action_items": [{
    "title": "string",
    "assignee": "string or null",
    "due_date": "YYYY-MM-DD or null",
    "target_module": "task",
    "evidence": "string or null"
  }],
  "risks": [{"title": "string", "level": "low|medium|high", "evidence": "string or null"}],
  "requires_human_approval": true
}
Never create final accounting or PMS approvals. Everything is a draft candidate.
"""


def _fallback_analysis(transcript: str) -> MeetingAnalysisResult:
    first_line = transcript.strip().splitlines()[0][:160]
    return MeetingAnalysisResult(
        summary=f"회의 내용 초안 요약: {first_line}",
        decisions=[],
        action_items=[],
        risks=[],
        requires_human_approval=True,
    )


async def analyze_meeting_transcript(transcript: str) -> MeetingAnalysisResult:
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": transcript},
        ],
        "options": {"temperature": 0.1},
    }

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                f"{settings.ollama_base_url}/api/chat",
                json=payload,
            )
            response.raise_for_status()
        content = response.json()["message"]["content"]
        return MeetingAnalysisResult.model_validate(json.loads(content))
    except Exception:
        return _fallback_analysis(transcript)

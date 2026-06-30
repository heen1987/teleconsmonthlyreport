from fastapi import APIRouter

from app.core.config import settings
from app.schemas import MeetingAnalysisRequest, MeetingAnalysisResponse
from app.services.llm import analyze_transcript

router = APIRouter(prefix="/analyze", tags=["analysis"])


@router.post("/meeting", response_model=MeetingAnalysisResponse)
async def analyze_meeting(payload: MeetingAnalysisRequest):
    result = await analyze_transcript(payload.transcript)
    return MeetingAnalysisResponse(
        job_id=payload.job_id,
        project_id=payload.project_id,
        meeting_id=payload.meeting_id,
        model_name=settings.ollama_model,
        status="draft",
        result=result,
    )

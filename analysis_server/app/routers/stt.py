from fastapi import APIRouter

from app.schemas import SttRequest, SttResponse
from app.services.stt import transcribe_audio_uri

router = APIRouter(prefix="/stt", tags=["stt"])


@router.post("/transcribe", response_model=SttResponse)
async def transcribe_audio(payload: SttRequest):
    transcript = await transcribe_audio_uri(payload.audio_path, payload.language)
    return SttResponse(
        job_id=payload.job_id,
        status="completed",
        transcript=transcript,
    )

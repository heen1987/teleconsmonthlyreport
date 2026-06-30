from fastapi import APIRouter

from app.schemas import AnalysisServerHealthOut
from app.services.analysis_client import get_analysis_server_health

router = APIRouter(prefix="/integrations", tags=["integrations"])


@router.get("/analysis-server/health", response_model=AnalysisServerHealthOut)
async def analysis_server_health():
    return await get_analysis_server_health()

from fastapi import APIRouter, Depends

from app.schemas import AnalysisServerHealthOut
from app.services.analysis_client import get_analysis_server_health
from app.services.auth_tokens import require_active_user

router = APIRouter(prefix="/integrations", tags=["integrations"])


@router.get("/analysis-server/health", response_model=AnalysisServerHealthOut)
async def analysis_server_health(_: dict = Depends(require_active_user)):
    return await get_analysis_server_health()

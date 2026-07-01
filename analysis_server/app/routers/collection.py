"""
Collection HTTP 라우터 — Android 클라이언트 전용 얇은 레이어

비즈니스 로직은 모두 app.services.collection 모듈에 있다.
이 파일은 HTTP ↔ 서비스 함수 변환만 담당한다.

노출 엔드포인트 (Android 가 호출하는 것만):
  POST   /collection/upload-sessions
  POST   /collection/upload-sessions/{session_id}/audio-file
  POST   /collection/audio-assets
  GET    /collection/audio-assets/{asset_id}
  POST   /collection/analysis-jobs
  GET    /collection/analysis-jobs
  GET    /collection/analysis-jobs/{job_id}

워커 제어 엔드포인트(heartbeat, claim, complete, fail 등)는
내부 asyncio 워커가 서비스 모듈을 직접 호출하므로 HTTP 로 노출하지 않는다.
"""

from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile

from app.schemas import (
    AnalysisJobCreate,
    AnalysisJobOut,
    AudioAssetCreate,
    AudioAssetOut,
    UploadSessionCreate,
    UploadSessionOut,
)
from app.services import collection as svc
from app.services.auth_tokens import require_user_or_internal_client

router = APIRouter(prefix="/collection", tags=["collection"])


# ── 업로드 세션 ──────────────────────────────────────────────────────────────

@router.post("/upload-sessions", response_model=UploadSessionOut)
def create_upload_session(
    payload: UploadSessionCreate,
    _auth: dict = Depends(require_user_or_internal_client),
):
    return svc.create_upload_session(
        project_id=payload.project_id,
        meeting_id=payload.meeting_id,
        requested_by=payload.requested_by,
        file_name=payload.file_name,
        content_type=payload.content_type,
        expected_size_bytes=payload.expected_size_bytes,
        checksum_sha256=payload.checksum_sha256,
        expires_at=payload.expires_at,
    )


# ── 오디오 파일 업로드 ────────────────────────────────────────────────────────

@router.post("/upload-sessions/{session_id}/audio-file", response_model=AudioAssetOut)
async def upload_audio_file(
    session_id: str,
    file: UploadFile = File(...),
    x_upload_token: str = Header(..., alias="X-Upload-Token"),
    _auth: dict = Depends(require_user_or_internal_client),
):
    content = await file.read()
    try:
        return svc.store_audio_file(
            session_id=session_id,
            upload_token=x_upload_token,
            content=content,
            filename=file.filename,
            mime=file.content_type,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


# ── 오디오 에셋 (URI 직접 등록) ───────────────────────────────────────────────

@router.post("/audio-assets", response_model=AudioAssetOut)
def register_audio_asset(
    payload: AudioAssetCreate,
    _auth: dict = Depends(require_user_or_internal_client),
):
    try:
        return svc.register_audio_asset(
            session_id=payload.session_id,
            storage_uri=payload.storage_uri,
            file_name=payload.file_name,
            content_type=payload.content_type,
            size_bytes=payload.size_bytes,
            checksum_sha256=payload.checksum_sha256,
            duration_seconds=payload.duration_seconds,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/audio-assets/{asset_id}", response_model=AudioAssetOut)
def get_audio_asset(
    asset_id: str,
    _auth: dict = Depends(require_user_or_internal_client),
):
    asset = svc.get_audio_asset(asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Audio asset not found")
    return asset


# ── 분석 Job ────────────────────────────────────────────────────────────────

@router.post("/analysis-jobs", response_model=AnalysisJobOut)
def create_analysis_job(
    payload: AnalysisJobCreate,
    _auth: dict = Depends(require_user_or_internal_client),
):
    try:
        return svc.create_analysis_job(
            session_id=payload.session_id,
            asset_id=payload.asset_id,
            transcript_text=payload.transcript_text,
            language=payload.language,
            priority=payload.priority,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/analysis-jobs", response_model=list[AnalysisJobOut])
def list_analysis_jobs(
    status: str | None = None,
    meeting_id: str | None = None,
    _auth: dict = Depends(require_user_or_internal_client),
):
    return svc.list_analysis_jobs(status=status, meeting_id=meeting_id)


@router.get("/analysis-jobs/{job_id}", response_model=AnalysisJobOut)
def get_analysis_job(
    job_id: str,
    _auth: dict = Depends(require_user_or_internal_client),
):
    job = svc.get_analysis_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Analysis job not found")
    return job

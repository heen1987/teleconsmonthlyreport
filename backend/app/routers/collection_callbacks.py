import hashlib
import hmac
import json
import time

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import ValidationError

from app.core.config import settings
from app.schemas import CollectionJobCompleteCallback, CollectionJobCompleteOut
from app.services.meeting_analysis_store import (
    MeetingAnalysisConflictError,
    MeetingAnalysisProjectMismatchError,
    MeetingAnalysisStoreError,
    store_draft_meeting_analysis,
)

router = APIRouter(prefix="/integrations/collection", tags=["collection integration"])


def _parse_previous_callback_secrets(raw_value: str) -> dict[str, str]:
    if not raw_value.strip():
        return {}
    try:
        parsed = json.loads(raw_value)
    except json.JSONDecodeError:
        parsed = None
    if isinstance(parsed, dict):
        return {str(key).strip(): str(value) for key, value in parsed.items() if str(key).strip() and str(value)}

    secrets: dict[str, str] = {}
    for item in raw_value.split(","):
        pair = item.strip()
        if not pair:
            continue
        if "=" not in pair:
            raise HTTPException(
                status_code=500,
                detail="Invalid COLLECTION_CALLBACK_PREVIOUS_SECRETS format",
            )
        key_id, secret = pair.split("=", 1)
        key_id = key_id.strip()
        secret = secret.strip()
        if key_id and secret:
            secrets[key_id] = secret
    return secrets


def _callback_secret_candidates(key_id: str | None) -> dict[str, str]:
    active_key_id = settings.collection_callback_secret_id.strip()
    if not active_key_id:
        raise HTTPException(status_code=500, detail="COLLECTION_CALLBACK_SECRET_ID is not configured")

    secrets = _parse_previous_callback_secrets(settings.collection_callback_previous_secrets)
    secrets[active_key_id] = settings.collection_callback_secret

    if key_id:
        selected = secrets.get(key_id)
        if selected is None:
            raise HTTPException(status_code=401, detail="Unknown Collection callback key id")
        return {key_id: selected}
    return secrets


def _verify_callback_signature(
    *,
    raw_body: bytes,
    key_id: str | None,
    timestamp: str | None,
    signature: str | None,
):
    if not timestamp or not signature:
        raise HTTPException(status_code=401, detail="Missing Collection callback signature")
    try:
        timestamp_int = int(timestamp)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid Collection callback timestamp") from exc
    if abs(int(time.time()) - timestamp_int) > settings.collection_callback_max_age_seconds:
        raise HTTPException(status_code=401, detail="Expired Collection callback timestamp")

    if not signature.startswith("sha256="):
        raise HTTPException(status_code=401, detail="Invalid Collection callback signature scheme")

    signed_payload = timestamp.encode("utf-8") + b"." + raw_body
    for secret in _callback_secret_candidates(key_id).values():
        expected = hmac.new(
            secret.encode("utf-8"),
            signed_payload,
            hashlib.sha256,
        ).hexdigest()
        expected_header = f"sha256={expected}"
        if hmac.compare_digest(signature, expected_header):
            return
    raise HTTPException(status_code=401, detail="Invalid Collection callback signature")


@router.post("/jobs/{job_id}/complete", response_model=CollectionJobCompleteOut)
async def complete_collection_job(
    job_id: str,
    request: Request,
    x_collection_key_id: str | None = Header(default=None, alias="X-Collection-Key-Id"),
    x_collection_timestamp: str | None = Header(default=None, alias="X-Collection-Timestamp"),
    x_collection_signature: str | None = Header(default=None, alias="X-Collection-Signature"),
):
    raw_body = await request.body()
    _verify_callback_signature(
        raw_body=raw_body,
        key_id=x_collection_key_id,
        timestamp=x_collection_timestamp,
        signature=x_collection_signature,
    )
    try:
        payload = CollectionJobCompleteCallback.model_validate(json.loads(raw_body))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=422, detail="Invalid JSON body") from exc
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=exc.errors()) from exc

    if job_id != payload.job_id:
        raise HTTPException(status_code=400, detail="Path job_id does not match payload job_id")

    try:
        analysis_id, created, analysis_status = store_draft_meeting_analysis(
            meeting_id=payload.meeting_id,
            project_id=payload.project_id,
            model_name=payload.model_name,
            result=payload.result,
            source_collection_job_id=payload.job_id,
            source_asset_id=payload.asset_id,
            audio_path=payload.audio_path,
            transcript=payload.transcript,
        )
    except (MeetingAnalysisProjectMismatchError, MeetingAnalysisConflictError) as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except MeetingAnalysisStoreError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return CollectionJobCompleteOut(
        job_id=payload.job_id,
        meeting_id=payload.meeting_id,
        analysis_id=analysis_id,
        status=analysis_status,
        created=created,
    )

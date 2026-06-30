#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p tmp
say -v Yuna -o tmp/meeting-upload-test.aiff \
  "김희섭은 안드로이드 음성 업로드 연동을 오늘 완료하기로 했습니다. 테스트 장비 한 대가 필요합니다. 일정 지연 리스크가 있습니다. 분석 작업은 컬렉션 에이피아이에서 관리하기로 결정했습니다."
ffmpeg -y -i tmp/meeting-upload-test.aiff -ar 16000 -ac 1 tmp/meeting-upload-test.wav >/tmp/ai-pms-ffmpeg.log 2>&1

backend/.venv/bin/python - <<'PY'
import hashlib
import hmac
import json
import os
import sys
from pathlib import Path
import time
from concurrent.futures import ThreadPoolExecutor

from dotenv import dotenv_values
import httpx
import psycopg
from psycopg.rows import dict_row

sys.path.insert(0, str(Path("backend").resolve()))

from app.db.session import get_connection
from app.schemas import UserCreate
from app.services.users import create_user_record


platform = "http://127.0.0.1:8000"
collection = "http://127.0.0.1:8200"
callback_secret = (
    dotenv_values("backend/.env").get("COLLECTION_CALLBACK_SECRET")
    or os.getenv("COLLECTION_CALLBACK_SECRET")
    or "dev-collection-callback-secret"
)
callback_key_id = (
    dotenv_values("backend/.env").get("COLLECTION_CALLBACK_SECRET_ID")
    or os.getenv("COLLECTION_CALLBACK_SECRET_ID")
    or "dev-v1"
)
collection_database_url = (
    dotenv_values("collection_api/.env").get("DATABASE_URL")
    or os.getenv("DATABASE_URL")
    or "postgresql://ai_pms:ai_pms@localhost:5432/ai_pms"
)
audio_path = Path("tmp/meeting-upload-test.wav")
content = audio_path.read_bytes()
checksum = hashlib.sha256(content).hexdigest()
stamp = time.strftime("%H%M%S")
project_id = f"PJT-AUDIO-{stamp}"
meeting_id = f"MTG-AUDIO-{stamp}"

with get_connection() as connection:
    with connection.cursor(row_factory=dict_row) as cursor:
        user = create_user_record(
            cursor,
            UserCreate(
                employee_no=f"AUD{stamp}",
                name="김희섭",
                email=f"audio{stamp}@local.test",
                role="pm",
                initial_password="1234",
            ),
        )


def canonical_body(payload: dict) -> bytes:
    return json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def signed_headers(raw_body: bytes) -> dict[str, str]:
    timestamp = str(int(time.time()))
    digest = hmac.new(
        callback_secret.encode("utf-8"),
        timestamp.encode("utf-8") + b"." + raw_body,
        hashlib.sha256,
    ).hexdigest()
    return {
        "Content-Type": "application/json",
        "X-Collection-Key-Id": callback_key_id,
        "X-Collection-Timestamp": timestamp,
        "X-Collection-Signature": f"sha256={digest}",
    }


def signed_callback_payload(job_id: str, project_id_override: str | None = None) -> dict:
    return {
        "job_id": job_id,
        "project_id": project_id_override or project_id,
        "meeting_id": meeting_id,
        "asset_id": asset["asset_id"],
        "audio_path": asset["storage_uri"],
        "transcript": current.get("transcript_text"),
        "model_name": current.get("model_name") or "unknown",
        "result": current["result_json"],
    }


def post_signed_callback(payload: dict) -> tuple[int, dict | str]:
    raw_body = canonical_body(payload)
    response = httpx.post(
        f"{platform}/integrations/collection/jobs/{payload['job_id']}/complete",
        content=raw_body,
        headers=signed_headers(raw_body),
        timeout=30,
    )
    try:
        body = response.json()
    except json.JSONDecodeError:
        body = response.text
    return response.status_code, body

with httpx.Client(timeout=420) as client:
    platform_headers: dict[str, str] = {}

    initial_login = client.post(
        f"{platform}/users/login",
        json={"employee_no": user["employee_no"], "password": "1234"},
    ).raise_for_status().json()
    client.post(
        f"{platform}/users/password/change",
        json={
            "employee_no": user["employee_no"],
            "current_password": "1234",
            "new_password": f"pw{stamp}",
        },
        headers={"Authorization": f"Bearer {initial_login['access_token']}"},
    ).raise_for_status()
    active_login = client.post(
        f"{platform}/users/login",
        json={"employee_no": user["employee_no"], "password": f"pw{stamp}"},
    ).raise_for_status().json()
    platform_headers = {"Authorization": f"Bearer {active_login['access_token']}"}

    client.post(
        f"{platform}/projects",
        headers=platform_headers,
        json={
            "project_id": project_id,
            "name": "오디오 업로드 Callback 검증",
            "pm_user_id": user["user_id"],
        },
    ).raise_for_status()
    client.post(
        f"{platform}/projects/{project_id}/members",
        headers=platform_headers,
        json={"user_id": user["user_id"], "project_role": "pm"},
    ).raise_for_status()
    client.post(
        f"{platform}/meetings",
        headers=platform_headers,
        json={
            "meeting_id": meeting_id,
            "project_id": project_id,
            "title": "오디오 업로드 Callback 회의",
            "created_by": user["user_id"],
        },
    ).raise_for_status()

    session = client.post(
        f"{collection}/upload-sessions",
        json={
            "project_id": project_id,
            "meeting_id": meeting_id,
            "requested_by": user["user_id"],
            "file_name": audio_path.name,
            "content_type": "audio/wav",
            "expected_size_bytes": len(content),
            "checksum_sha256": checksum,
        },
    ).raise_for_status().json()

    with audio_path.open("rb") as file_obj:
        asset = client.post(
            f"{collection}/upload-sessions/{session['session_id']}/audio-file",
            headers={"X-Upload-Token": session["upload_token"]},
            files={"file": (audio_path.name, file_obj, "audio/wav")},
        ).raise_for_status().json()

    job = client.post(
        f"{collection}/analysis-jobs",
        json={
            "session_id": session["session_id"],
            "asset_id": asset["asset_id"],
            "language": "ko",
            "priority": 100,
        },
    ).raise_for_status().json()

    deadline = time.time() + 420
    review = None
    while True:
        current = client.get(f"{collection}/analysis-jobs/{job['job_id']}").raise_for_status().json()
        try:
            review = client.get(
                f"{platform}/meetings/{meeting_id}/review-package",
                headers=platform_headers,
            ).raise_for_status().json()
            break
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code != 404:
                raise
        if current["status"] in {"failed", "cancelled"}:
            raise RuntimeError(current)
        if time.time() > deadline:
            raise TimeoutError(current)
        time.sleep(3)

    unsigned_callback = client.post(
        f"{platform}/integrations/collection/jobs/{job['job_id']}/complete",
        json={
            "job_id": job["job_id"],
            "project_id": project_id,
            "meeting_id": meeting_id,
            "asset_id": asset["asset_id"],
            "audio_path": asset["storage_uri"],
            "transcript": current.get("transcript_text"),
            "model_name": current.get("model_name") or "unknown",
            "result": current["result_json"],
        },
    )
    if unsigned_callback.status_code != 401:
        raise RuntimeError(
            {
                "expected_unsigned_callback_status": 401,
                "actual_status": unsigned_callback.status_code,
                "body": unsigned_callback.text,
            }
        )

    replay = client.post(
        f"{collection}/analysis-jobs/{job['job_id']}/notify-platform"
    ).raise_for_status().json()
    events = client.get(
        f"{collection}/analysis-jobs/{job['job_id']}/events"
    ).raise_for_status().json()
    event_types = [event["event_type"] for event in events]
    if "platform_callback_succeeded" not in event_types:
        raise RuntimeError({"missing_event": "platform_callback_succeeded", "events": event_types})

    duplicate_payload = signed_callback_payload(job["job_id"])
    with ThreadPoolExecutor(max_workers=4) as pool:
        duplicate_results = list(pool.map(lambda _: post_signed_callback(duplicate_payload), range(4)))
    for status_code, body in duplicate_results:
        if status_code != 200 or body.get("analysis_id") != review["analysis_id"] or body.get("created") is not False:
            raise RuntimeError({"unexpected_duplicate_callback_result": duplicate_results})

    mismatch_payload = signed_callback_payload(
        f"{job['job_id']}-mismatch",
        project_id_override="PJT-NOT-THE-MEETING",
    )
    mismatch_status, mismatch_body = post_signed_callback(mismatch_payload)
    if mismatch_status != 409:
        raise RuntimeError(
            {
                "expected_project_mismatch_status": 409,
                "actual_status": mismatch_status,
                "body": mismatch_body,
            }
        )

    with psycopg.connect(collection_database_url) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE collection_analysis_jobs
                SET platform_callback_status = 'retry_wait',
                    platform_callback_attempt_count = 0,
                    platform_callback_next_attempt_at = now(),
                    platform_callback_last_error = 'smoke forced retry'
                WHERE job_id = %s
                """,
                (job["job_id"],),
            )
    retry_due = client.post(
        f"{collection}/analysis-jobs/callbacks/retry-due",
        params={"limit": 5},
    ).raise_for_status().json()
    retry_statuses = [result["status"] for result in retry_due["results"]]
    if retry_due["retried"] < 1 or "succeeded" not in retry_statuses:
        raise RuntimeError({"unexpected_retry_due_result": retry_due})

    callback_state = client.get(
        f"{collection}/analysis-jobs/{job['job_id']}"
    ).raise_for_status().json()
    if callback_state.get("platform_callback_status") != "succeeded":
        raise RuntimeError({"unexpected_callback_state": callback_state})

    edited_result = json.loads(json.dumps(review["result"]))
    edited_result["summary"] = f"{edited_result['summary']} [검토 수정]"
    for action_item in edited_result.get("action_items", []):
        action_item["task_conversion_status"] = "rejected"
        action_item["task_conversion_reason"] = "smoke review edit rejection"
    edited_review = client.put(
        f"{platform}/meetings/analyses/{review['analysis_id']}/review-edits",
        headers=platform_headers,
        json={
            "result": edited_result,
            "actor_user_id": user["user_id"],
            "edit_reason": "smoke review edit before approval",
        },
    ).raise_for_status().json()
    if not edited_review["result"]["summary"].endswith("[검토 수정]"):
        raise RuntimeError({"unexpected_edited_summary": edited_review["result"]["summary"]})
    if any(
        item.get("task_conversion_status") != "rejected"
        for item in edited_review["result"].get("action_items", [])
    ):
        raise RuntimeError({"unexpected_edited_action_items": edited_review["result"].get("action_items", [])})

    approval = client.post(
        f"{platform}/approvals/meeting-analyses/{review['analysis_id']}/approve",
        headers=platform_headers,
    ).raise_for_status().json()
    if approval["created_tasks"] != 0:
        raise RuntimeError({"expected_created_tasks": 0, "approval": approval})

print(
    {
        "project_id": project_id,
        "meeting_id": meeting_id,
        "session_id": session["session_id"],
        "asset_id": asset["asset_id"],
        "job_id": job["job_id"],
        "job_status": current["status"],
        "review_analysis_id": review["analysis_id"],
        "review_counts": review["counts"],
        "unsigned_callback_status": unsigned_callback.status_code,
        "replay": replay,
        "duplicate_callback_statuses": [status_code for status_code, _body in duplicate_results],
        "mismatch_callback_status": mismatch_status,
        "retry_due": retry_due,
        "platform_callback_status": callback_state.get("platform_callback_status"),
        "edited_summary": edited_review["result"]["summary"],
        "approval": approval,
    }
)
PY

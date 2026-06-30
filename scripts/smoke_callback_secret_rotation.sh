#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR/backend"

.venv/bin/python - <<'PY'
import hashlib
import hmac
import json
import time

from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app


client = TestClient(app)

payload = {
    "job_id": "CJOB-SECRET-ROTATION",
    "project_id": "PJT-SECRET-ROTATION",
    "meeting_id": "MTG-SECRET-ROTATION",
    "asset_id": None,
    "audio_path": None,
    "transcript": "secret rotation smoke",
    "model_name": "qwen3:4b",
    "result": {
        "schema_version": "analysis.v1",
        "language": "ko",
        "summary": "secret rotation smoke",
        "transcript_segments": [
            {
                "segment_id": "seg-secret-rotation",
                "text": "secret rotation smoke",
            }
        ],
        "decisions": [],
        "action_items": [],
        "risks": [],
        "required_resources": [],
        "requires_human_approval": True,
    },
}


def canonical_body(value: dict) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def headers(raw_body: bytes, key_id: str | None, secret: str) -> dict[str, str]:
    timestamp = str(int(time.time()))
    digest = hmac.new(
        secret.encode("utf-8"),
        timestamp.encode("utf-8") + b"." + raw_body,
        hashlib.sha256,
    ).hexdigest()
    result = {
        "Content-Type": "application/json",
        "X-Collection-Timestamp": timestamp,
        "X-Collection-Signature": f"sha256={digest}",
    }
    if key_id is not None:
        result["X-Collection-Key-Id"] = key_id
    return result


raw = canonical_body(payload)
original = {
    "collection_callback_secret_id": settings.collection_callback_secret_id,
    "collection_callback_secret": settings.collection_callback_secret,
    "collection_callback_previous_secrets": settings.collection_callback_previous_secrets,
}

try:
    settings.collection_callback_secret_id = "new-v2"
    settings.collection_callback_secret = "new-secret"
    settings.collection_callback_previous_secrets = "old-v1=old-secret"

    accepted_statuses = {404, 409}

    active_response = client.post(
        "/integrations/collection/jobs/CJOB-SECRET-ROTATION/complete",
        content=raw,
        headers=headers(raw, "new-v2", "new-secret"),
    )
    assert active_response.status_code in accepted_statuses, active_response.text

    previous_response = client.post(
        "/integrations/collection/jobs/CJOB-SECRET-ROTATION/complete",
        content=raw,
        headers=headers(raw, "old-v1", "old-secret"),
    )
    assert previous_response.status_code in accepted_statuses, previous_response.text

    legacy_previous_response = client.post(
        "/integrations/collection/jobs/CJOB-SECRET-ROTATION/complete",
        content=raw,
        headers=headers(raw, None, "old-secret"),
    )
    assert legacy_previous_response.status_code in accepted_statuses, legacy_previous_response.text

    unknown_key_response = client.post(
        "/integrations/collection/jobs/CJOB-SECRET-ROTATION/complete",
        content=raw,
        headers=headers(raw, "unknown-v0", "old-secret"),
    )
    assert unknown_key_response.status_code == 401, unknown_key_response.text

    invalid_response = client.post(
        "/integrations/collection/jobs/CJOB-SECRET-ROTATION/complete",
        content=raw,
        headers=headers(raw, "new-v2", "wrong-secret"),
    )
    assert invalid_response.status_code == 401, invalid_response.text
finally:
    settings.collection_callback_secret_id = original["collection_callback_secret_id"]
    settings.collection_callback_secret = original["collection_callback_secret"]
    settings.collection_callback_previous_secrets = original["collection_callback_previous_secrets"]

print(
    {
        "active_key_id": "accepted",
        "previous_key_id": "accepted",
        "legacy_without_key_id": "accepted",
        "unknown_key_id": "rejected",
        "invalid_signature": "rejected",
    }
)
PY

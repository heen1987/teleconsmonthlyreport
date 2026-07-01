#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TUNNEL_DIR="$ROOT_DIR/runtime/tunnels"

extract_url() {
  local service="$1"
  local log_file="$TUNNEL_DIR/$service.log"
  if [ ! -f "$log_file" ]; then
    echo "Missing tunnel log: $log_file" >&2
    return 1
  fi
  grep -aEo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -1
}

resolve_url() {
  local service="$1"
  local positional="$2"
  local env_value="$3"
  local url="$positional"
  if [ -z "$url" ]; then
    url="$env_value"
  fi
  if [ -z "$url" ]; then
    url="$(extract_url "$service" || true)"
  fi
  url="${url%/}"
  if [ -z "$url" ]; then
    echo "Missing public URL for $service." >&2
    exit 1
  fi
  printf "%s" "$url"
}

resolve_platform_url() {
  local positional="$1"
  local env_value="$2"
  local url="$positional"
  if [ -z "$url" ]; then
    url="$env_value"
  fi
  url="${url%/}"
  if [ -z "$url" ]; then
    echo "Missing public URL for Platform. Set AIPMS_GITHUB_PAGES_URL, AIPMS_PLATFORM_URL, or AIPMS_PLATFORM_API_URL." >&2
    exit 1
  fi
  case "$url" in
    http://127.*|https://127.*|http://localhost*|https://localhost*|\
    http://10.*|https://10.*|http://192.168.*|https://192.168.*|\
    http://172.1[6-9].*|https://172.1[6-9].*|http://172.2[0-9].*|https://172.2[0-9].*|\
    http://172.3[0-1].*|https://172.3[0-1].*)
      echo "Platform URL must point to the Platform server, not a local/LAN IP: $url" >&2
      exit 2
      ;;
  esac
  printf "%s" "$url"
}

DEFAULT_GITHUB_PAGES_PLATFORM_URL="${AIPMS_GITHUB_PAGES_URL:-https://heen1987.github.io/teleconsmonthlyreport}"
AIPMS_PUBLIC_WEB_URL="$(resolve_url web "${1:-}" "${AIPMS_PUBLIC_WEB_URL:-}")"
AIPMS_PUBLIC_PLATFORM_URL="$(resolve_platform_url "${2:-}" "${AIPMS_PUBLIC_PLATFORM_URL:-${AIPMS_PLATFORM_API_URL:-${AIPMS_PLATFORM_URL:-$DEFAULT_GITHUB_PAGES_PLATFORM_URL}}}")"
AIPMS_PUBLIC_COLLECTION_URL="$(resolve_url collection "${3:-}" "${AIPMS_PUBLIC_COLLECTION_URL:-}")"
AIPMS_PUBLIC_ANALYSIS_URL="${4:-${AIPMS_PUBLIC_ANALYSIS_URL:-$AIPMS_PUBLIC_COLLECTION_URL}}"
export AIPMS_PUBLIC_WEB_URL
export AIPMS_PUBLIC_PLATFORM_URL
export AIPMS_PUBLIC_COLLECTION_URL
export AIPMS_PUBLIC_ANALYSIS_URL
export AIPMS_PUBLIC_FLOW_OUTPUT="${AIPMS_PUBLIC_FLOW_OUTPUT:-$ROOT_DIR/runtime/public_handoff/latest_external_flow_check.json}"
export AIPMS_PUBLIC_FLOW_TIMEOUT_SECONDS="${AIPMS_PUBLIC_FLOW_TIMEOUT_SECONDS:-360}"
export AIPMS_PUBLIC_FLOW_POLL_SECONDS="${AIPMS_PUBLIC_FLOW_POLL_SECONDS:-5}"
export AIPMS_PUBLIC_FLOW_SENDING_REPLAY_AFTER_SECONDS="${AIPMS_PUBLIC_FLOW_SENDING_REPLAY_AFTER_SECONDS:-45}"
export AIPMS_PUBLIC_FLOW_EMPLOYEE_NO="${AIPMS_PUBLIC_FLOW_EMPLOYEE_NO:-admin}"
export AIPMS_PUBLIC_FLOW_PASSWORD="${AIPMS_PUBLIC_FLOW_PASSWORD:-1234}"

python3 - <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import time
import uuid
import urllib.error
import urllib.request
from pathlib import Path


WEB_URL = os.environ["AIPMS_PUBLIC_WEB_URL"].rstrip("/")
PLATFORM_URL = os.environ["AIPMS_PUBLIC_PLATFORM_URL"].rstrip("/")
COLLECTION_URL = os.environ["AIPMS_PUBLIC_COLLECTION_URL"].rstrip("/")
ANALYSIS_URL = os.environ["AIPMS_PUBLIC_ANALYSIS_URL"].rstrip("/")
OUTPUT = Path(os.environ["AIPMS_PUBLIC_FLOW_OUTPUT"])
TIMEOUT_SECONDS = int(os.environ["AIPMS_PUBLIC_FLOW_TIMEOUT_SECONDS"])
POLL_SECONDS = int(os.environ["AIPMS_PUBLIC_FLOW_POLL_SECONDS"])
SENDING_REPLAY_AFTER_SECONDS = int(os.environ["AIPMS_PUBLIC_FLOW_SENDING_REPLAY_AFTER_SECONDS"])
EMPLOYEE_NO = os.environ["AIPMS_PUBLIC_FLOW_EMPLOYEE_NO"]
PASSWORD = os.environ["AIPMS_PUBLIC_FLOW_PASSWORD"]


def write_result(result: dict) -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def request_json(method: str, url: str, *, token: str | None = None, body: dict | None = None, timeout: int = 60) -> dict:
    headers = {"Accept": "application/json"}
    data = None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
            return json.loads(raw.decode("utf-8")) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {url} failed: HTTP {exc.code} {detail}") from exc


def upload_multipart(url: str, *, token: str, upload_token: str, file_name: str, content: bytes) -> dict:
    boundary = f"----aipms-{uuid.uuid4().hex}"
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="file"; filename="{file_name}"\r\n'.encode(),
            b"Content-Type: audio/wav\r\n\r\n",
            content,
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "X-Upload-Token": upload_token,
    }
    req = urllib.request.Request(url, data=body, method="POST", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"POST {url} failed: HTTP {exc.code} {detail}") from exc


def main() -> None:
    suffix = uuid.uuid4().hex[:8]
    project_id = f"EXT-PUB-{suffix}"
    meeting_id = f"EXT-MTG-{suffix}"
    result = {
        "public_external_flow": "running",
        "web_url": WEB_URL,
        "platform_url": PLATFORM_URL,
        "collection_url": COLLECTION_URL,
        "analysis_url": ANALYSIS_URL,
        "project_id": project_id,
        "meeting_id": meeting_id,
        "upload_session_id": None,
        "asset_id": None,
        "job_id": None,
        "job_status": None,
        "platform_callback_status": None,
        "meeting_status": None,
        "review_status_code": None,
        "analysis_id": None,
        "review_counts": None,
    }
    write_result(result)

    login = request_json(
        "POST",
        f"{PLATFORM_URL}/users/login",
        body={"employee_no": EMPLOYEE_NO, "password": PASSWORD},
    )
    token = login["access_token"]
    user = login["user"]

    request_json(
        "POST",
        f"{PLATFORM_URL}/projects",
        token=token,
        body={
            "project_id": project_id,
            "name": f"외부 연동 검수 {suffix}",
            "description": "외부 공개망 앱-수집-분석-플랫폼-Web 연동 검수용 프로젝트",
            "pm_user_id": user["user_id"],
        },
    )
    request_json(
        "POST",
        f"{PLATFORM_URL}/meetings",
        token=token,
        body={
            "meeting_id": meeting_id,
            "project_id": project_id,
            "title": f"외부 연동 검수 회의 {suffix}",
        },
    )

    audio_bytes = (
        b"AI-PMS external flow smoke audio placeholder. "
        b"The transcript_text field drives analysis while upload storage is verified."
    )
    checksum = hashlib.sha256(audio_bytes).hexdigest()
    upload_session = request_json(
        "POST",
        f"{COLLECTION_URL}/upload-sessions",
        token=token,
        body={
            "project_id": project_id,
            "meeting_id": meeting_id,
            "requested_by": user["user_id"],
            "file_name": f"external-flow-{suffix}.wav",
            "content_type": "audio/wav",
            "expected_size_bytes": len(audio_bytes),
            "checksum_sha256": checksum,
        },
    )
    session_id = upload_session["session_id"]
    result["upload_session_id"] = session_id
    write_result(result)

    asset = upload_multipart(
        f"{COLLECTION_URL}/upload-sessions/{session_id}/audio-file",
        token=token,
        upload_token=upload_session["upload_token"],
        file_name=f"external-flow-{suffix}.wav",
        content=audio_bytes,
    )
    result["asset_id"] = asset["asset_id"]
    write_result(result)

    transcript = (
        "AI-PMS 외부 연동 검수 회의입니다. "
        "프로젝트 선택 후 녹음 파일 업로드가 완료되었습니다. "
        "결정사항은 Collection API 외부 접근을 유지하고 Platform callback을 검증한다입니다. "
        "후속조치는 모바일 앱 APK 설치 후 실제 녹음 업로드를 확인한다입니다. "
        "리스크는 공개 터널 URL 변경이며 운영 시 고정 터널 전환이 필요합니다."
    )
    job = request_json(
        "POST",
        f"{COLLECTION_URL}/analysis-jobs",
        token=token,
        body={
            "session_id": session_id,
            "asset_id": asset["asset_id"],
            "priority": 10,
            "transcript_text": transcript,
            "language": "ko",
        },
    )
    job_id = job["job_id"]
    result["job_id"] = job_id
    result["job_status"] = job["status"]
    result["platform_callback_status"] = job.get("platform_callback_status")
    write_result(result)

    deadline = time.monotonic() + TIMEOUT_SECONDS
    callback_retry_sent = False
    sending_seen_at: float | None = None
    while time.monotonic() < deadline:
        time.sleep(POLL_SECONDS)
        job = request_json("GET", f"{COLLECTION_URL}/analysis-jobs/{job_id}", token=token)
        result["job_status"] = job["status"]
        result["platform_callback_status"] = job.get("platform_callback_status")
        write_result(result)
        print(
            json.dumps(
                {
                    "job_id": job_id,
                    "job_status": result["job_status"],
                    "platform_callback_status": result["platform_callback_status"],
                },
                ensure_ascii=False,
            )
            ,
            flush=True,
        )

        if job["status"] == "failed":
            raise RuntimeError(f"analysis job failed: {job.get('platform_callback_last_error')}")

        if job["status"] == "completed" and job.get("platform_callback_status") in {"pending", "retry_wait"} and not callback_retry_sent:
            callback_retry_sent = True
            request_json("POST", f"{COLLECTION_URL}/analysis-jobs/{job_id}/notify-platform", token=token)
            continue

        if job["status"] == "completed" and job.get("platform_callback_status") == "sending":
            now = time.monotonic()
            if sending_seen_at is None:
                sending_seen_at = now
            elif not callback_retry_sent and now - sending_seen_at >= SENDING_REPLAY_AFTER_SECONDS:
                callback_retry_sent = True
                request_json("POST", f"{COLLECTION_URL}/analysis-jobs/{job_id}/notify-platform", token=token)
            continue

        if job["status"] == "completed" and job.get("platform_callback_status") == "succeeded":
            meeting_status = request_json("GET", f"{PLATFORM_URL}/meetings/{meeting_id}/status", token=token)
            result["meeting_status"] = meeting_status["status"]
            try:
                review = request_json("GET", f"{PLATFORM_URL}/meetings/{meeting_id}/review-package", token=token)
            except RuntimeError:
                continue
            result["review_status_code"] = 200
            result["analysis_id"] = review["analysis_id"]
            result["review_counts"] = review["counts"]
            result["public_external_flow"] = "passed"
            write_result(result)
            print(json.dumps(result, ensure_ascii=False, indent=2))
            return

    raise RuntimeError(f"public external flow timed out after {TIMEOUT_SECONDS}s; latest={result}")


try:
    main()
except Exception as exc:
    current = {}
    if OUTPUT.exists():
        try:
            current = json.loads(OUTPUT.read_text(encoding="utf-8"))
        except Exception:
            current = {}
    current["public_external_flow"] = "failed"
    current["error"] = str(exc)
    write_result(current)
    raise
PY

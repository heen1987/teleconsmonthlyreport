#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIMIT="${1:-10}"
EMAIL_LIMIT="${AIPMS_EMAIL_RECOVERY_LIMIT:-$LIMIT}"
ERP_LIMIT="${AIPMS_ERP_HANDOFF_RECOVERY_LIMIT:-$LIMIT}"

cd "$ROOT_DIR"

email_output="$(bash scripts/run_email_delivery_worker_once.sh "$EMAIL_LIMIT")"
erp_output="$(bash scripts/run_erp_handoff_worker_once.sh "$ERP_LIMIT")"

printf "email_delivery=%s\n" "$email_output"
printf "erp_handoff=%s\n" "$erp_output"

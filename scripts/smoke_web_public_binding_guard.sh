#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

rg -q 'WEB_BIND_HOST="\$\{AIPMS_WEB_BIND_HOST:-127\.0\.0\.1\}"' scripts/run_local_execution_stack.sh scripts/run_public_tunnels.sh
rg -q 'AIPMS_WEB_ALLOW_PUBLIC_BIND' \
  scripts/run_local_execution_stack.sh \
  scripts/run_public_tunnels.sh \
  scripts/windows_web_dev.ps1 \
  scripts/windows_run_web_client.ps1 \
  README.md \
  docs/09_kim_heeseop_work_structure.md \
  docs/15_mvp_first_implementation.md \
  web_client/README.md
rg -q 'Refusing to bind Web dev server to a public interface' \
  scripts/run_local_execution_stack.sh \
  scripts/run_public_tunnels.sh \
  scripts/windows_web_dev.ps1 \
  scripts/windows_run_web_client.ps1

if rg -q -- '--host 0\.0\.0\.0' \
  scripts/run_local_execution_stack.sh \
  scripts/run_public_tunnels.sh \
  scripts/windows_web_dev.ps1 \
  scripts/windows_run_web_client.ps1 \
  scripts/publish_public_execution_hub.sh \
  web_client/package.json \
  web_client/src/main.tsx
then
  echo "Web dev server run paths must not default to 0.0.0.0:3000." >&2
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  listen_output="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null || true)"
  if printf '%s\n' "$listen_output" | grep -E 'TCP (\*|0\.0\.0\.0|\[::\]):3000 ' >/dev/null; then
    echo "Web dev server is currently listening on a public interface:" >&2
    printf '%s\n' "$listen_output" >&2
    exit 1
  fi
fi

echo "web public binding guard passed"

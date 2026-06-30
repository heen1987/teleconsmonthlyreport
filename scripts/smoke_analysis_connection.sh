#!/usr/bin/env bash
set -euo pipefail

PLATFORM_URL="${PLATFORM_URL:-http://localhost:8000}"
ANALYSIS_URL="${ANALYSIS_URL:-http://localhost:8100}"

echo "Checking analysis server directly: $ANALYSIS_URL/health"
curl -fsS "$ANALYSIS_URL/health"
echo

echo "Checking platform -> analysis server link: $PLATFORM_URL/integrations/analysis-server/health"
curl -fsS "$PLATFORM_URL/integrations/analysis-server/health"
echo

echo "OK"

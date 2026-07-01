#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

python3 - <<'PY'
import os
from pathlib import Path

targets = [
    Path("backend/app"),
    Path("collection_api/app"),
    Path("analysis_server/app"),
    Path("scripts/validate_analysis_contract.py"),
]
python_files = []
skip_dirs = {"__pycache__", ".mypy_cache", ".pytest_cache", ".ruff_cache"}
for target in targets:
    if target.is_dir():
        for dirpath, dirnames, filenames in os.walk(target):
            dirnames[:] = [name for name in dirnames if name not in skip_dirs]
            python_files.extend(
                Path(dirpath) / name for name in filenames if name.endswith(".py")
            )
    else:
        python_files.append(target)
python_files = sorted(python_files)

checked_files = 0
skipped_offline_placeholders = []

for path in python_files:
    stat = path.stat()
    if stat.st_size > 0 and getattr(stat, "st_blocks", 1) == 0:
        skipped_offline_placeholders.append(str(path))
        continue
    source = path.read_text(encoding="utf-8")
    compile(source, str(path), "exec")
    checked_files += 1

print(f"Python syntax check passed: {checked_files} files")
if skipped_offline_placeholders:
    print(
        "Python syntax check skipped offline Google Drive placeholders: "
        + ", ".join(skipped_offline_placeholders)
    )
PY
python3 -m json.tool contracts/analysis_result.schema.json >/dev/null
python3 -m json.tool contracts/status_catalog.json >/dev/null
python3 -m json.tool contracts/web_review_package.example.json >/dev/null
python3 -m json.tool web_client/public/handoff/public-review-package.json >/dev/null
python3 scripts/validate_analysis_contract.py
bash scripts/smoke_mvp_scope_definition.sh
bash scripts/smoke_formal_requirements_definition.sh
bash scripts/smoke_requirements_publication.sh
if bash scripts/publish_public_review_package.sh >/tmp/aipms-public-review-publish.log 2>&1 \
  && bash scripts/publish_public_execution_hub.sh >/tmp/aipms-public-execution-publish.log 2>&1
then
  :
else
  echo "Public review/execution package refresh skipped during static verification." >&2
  cat /tmp/aipms-public-review-publish.log /tmp/aipms-public-execution-publish.log >&2 || true
fi
bash scripts/smoke_android_release_readiness.sh
bash scripts/smoke_portfolio_evidence_bundle.sh
bash scripts/smoke_local_environment_doctor.sh
bash scripts/smoke_public_handoff_doctor.sh
bash scripts/smoke_canva_screen_design_fixed.sh
bash scripts/smoke_user_facing_copy_guard.sh
bash scripts/smoke_collection_public_binding_guard.sh
bash scripts/smoke_core_api_public_binding_guard.sh
bash scripts/smoke_web_public_binding_guard.sh
bash scripts/smoke_apk_publication_freshness.sh

python3 - <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
import urllib.request

assertions = r'''
assert len(schema["paths"]) >= 20
assert "/meetings/{meeting_id}/attendees" in schema["paths"]
assert {"get", "put"}.issubset(schema["paths"]["/meetings/{meeting_id}/attendees"].keys())
assert "/meetings" in schema["paths"]
assert "get" in schema["paths"]["/meetings"]
assert "/meetings/{meeting_id}/status" in schema["paths"]
assert "get" in schema["paths"]["/meetings/{meeting_id}/status"]
assert "/users/me" in schema["paths"]
assert "/users/logout" in schema["paths"]
assert "/users/password-reset/request" in schema["paths"]
assert "/users/password-reset/verify" in schema["paths"]
assert "/users/password-reset/confirm" in schema["paths"]
assert "/admin/users/{user_id}" in schema["paths"]
assert "/admin/users/{user_id}/reset-password" in schema["paths"]
assert "/meetings/{meeting_id}/distribution-preview" in schema["paths"]
assert "/meetings/{meeting_id}/distribute" in schema["paths"]
assert "/meetings/{meeting_id}/distributions" in schema["paths"]
assert "/meetings/{meeting_id}/distributions/{distribution_id}/retry" in schema["paths"]
assert "/distributions/retry-due" in schema["paths"]
assert "/resources/demands/{demand_id}/allocations" in schema["paths"]
assert "/resources/allocations" in schema["paths"]
assert "/resources/allocations/conflict-risks" in schema["paths"]
assert "post" in schema["paths"]["/resources/allocations/conflict-risks"]
assert "/resources/allocations/{allocation_id}/status" in schema["paths"]
assert "/resources/allocations/{allocation_id}/usage" in schema["paths"]
assert "/resources/usage" in schema["paths"]
assert "/resources/usage/overrun-risks" in schema["paths"]
assert "post" in schema["paths"]["/resources/usage/overrun-risks"]
assert "/resources/cost-candidates" in schema["paths"]
assert "/resources/cost-candidates/overrun-risks" in schema["paths"]
assert "post" in schema["paths"]["/resources/cost-candidates/overrun-risks"]
assert "/resources/cost-candidates/{cost_id}/status" in schema["paths"]
assert "patch" in schema["paths"]["/resources/cost-candidates/{cost_id}/status"]
assert "/resources/cost-candidates/{cost_id}/erp-handoff" in schema["paths"]
assert "post" in schema["paths"]["/resources/cost-candidates/{cost_id}/erp-handoff"]
assert "/resources/cost-handoffs" in schema["paths"]
assert "get" in schema["paths"]["/resources/cost-handoffs"]
assert "/resources/cost-handoffs/send-due" in schema["paths"]
assert "post" in schema["paths"]["/resources/cost-handoffs/send-due"]
assert "/resources/cost-handoffs/{handoff_id}/send" in schema["paths"]
assert "post" in schema["paths"]["/resources/cost-handoffs/{handoff_id}/send"]
assert "/resources/cost-handoffs/{handoff_id}/status" in schema["paths"]
assert "patch" in schema["paths"]["/resources/cost-handoffs/{handoff_id}/status"]
assert "/resources/demands/unassigned-risks" in schema["paths"]
assert "post" in schema["paths"]["/resources/demands/unassigned-risks"]
assert "/resources/profiles" in schema["paths"]
assert "/resources/profiles/availability" in schema["paths"]
assert "/resources/profiles/{resource_id}/calendar-blocks" in schema["paths"]
assert {"get", "post"}.issubset(schema["paths"]["/resources/profiles/{resource_id}/calendar-blocks"].keys())
assert "/operations/queue-status" in schema["paths"]
assert "get" in schema["paths"]["/operations/queue-status"]
assert "/tasks/overdue-risks" in schema["paths"]
assert "post" in schema["paths"]["/tasks/overdue-risks"]
assert "/projects/{project_id}/knowledge-items" in schema["paths"]
assert "get" in schema["paths"]["/projects/{project_id}/knowledge-items"]
'''

code = f"""
from app.main import app
schema = app.openapi()
{assertions}
print(f"Platform OpenAPI paths: {{len(schema['paths'])}}")
"""

try:
    result = subprocess.run(
        [".venv/bin/python", "-c", code],
        cwd="backend",
        text=True,
        capture_output=True,
        timeout=20,
        check=False,
    )
except subprocess.TimeoutExpired:
    print(
        "Platform OpenAPI import timed out; using live local endpoint fallback.",
        file=sys.stderr,
    )
    with urllib.request.urlopen("http://127.0.0.1:8000/openapi.json", timeout=10) as response:
        schema = json.load(response)
    exec(assertions, {"schema": schema})
    print(f"Platform OpenAPI paths: {len(schema['paths'])} (live fallback)")
else:
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
PY

python3 - <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
import urllib.request

code = """
from app.main import app
schema = app.openapi()
assert len(schema["paths"]) >= 15
print(f"Collection OpenAPI paths: {len(schema['paths'])}")
"""

try:
    result = subprocess.run(
        [".venv/bin/python", "-c", code],
        cwd="collection_api",
        text=True,
        capture_output=True,
        timeout=20,
        check=False,
    )
except subprocess.TimeoutExpired:
    print(
        "Collection OpenAPI import timed out; using live local endpoint fallback.",
        file=sys.stderr,
    )
    with urllib.request.urlopen("http://127.0.0.1:8200/openapi.json", timeout=10) as response:
        schema = json.load(response)
    assert len(schema["paths"]) >= 15
    print(f"Collection OpenAPI paths: {len(schema['paths'])} (live fallback)")
else:
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
PY

bash scripts/build_web_client_static.sh

required_android_files=(
  "android_client/settings.gradle.kts"
  "android_client/build.gradle.kts"
  "android_client/src/main/AndroidManifest.xml"
  "android_client/src/main/res/values/strings.xml"
  "android_client/src/main/java/com/aipms/MainActivity.kt"
  "android_client/src/main/java/com/aipms/recording/AndroidAudioRecorder.kt"
  "android_client/src/main/java/com/aipms/client/AiPmsApiClient.kt"
  "android_client/src/main/java/com/aipms/client/AiPmsContracts.kt"
  "android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt"
  "android_client/src/main/java/com/aipms/client/MeetingUploadRepository.kt"
)

for file in "${required_android_files[@]}"; do
  test -f "$file" || {
    echo "Missing Android client file: $file" >&2
    exit 1
  }
done

rg -q 'id\("com\.android\.application"\)' android_client/build.gradle.kts
rg -q 'io\.ktor:ktor-client-android' android_client/build.gradle.kts
rg -q 'ffmpeg_bin' analysis_server/app/core/config.py
rg -q 'FFMPEG_BIN' analysis_server/.env.example
rg -q 'collection_callback_secret_id' backend/app/core/config.py
rg -q 'collection_callback_previous_secrets' backend/app/core/config.py
rg -q 'access_token_ttl_seconds' backend/app/core/config.py
rg -q 'password_reset_token_ttl_seconds' backend/app/core/config.py
rg -q 'email_delivery_mode' backend/app/core/config.py
rg -q 'email_retry_max_attempts' backend/app/core/config.py
rg -q 'erp_handoff_delivery_mode' backend/app/core/config.py
rg -q 'erp_handoff_endpoint_url' backend/app/core/config.py
rg -q 'erp_handoff_retry_max_attempts' backend/app/core/config.py
rg -q 'CREATE TABLE IF NOT EXISTS access_tokens' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS password_reset_tokens' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS email_distributions' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS email_delivery_attempts' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS resource_profiles' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS resource_calendar_blocks' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS resource_allocations' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS resource_usage_entries' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS project_cost_candidates' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS project_cost_handoffs' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS project_knowledge_items' backend/schema.sql
rg -q 'idx_project_knowledge_items_project_kind' backend/schema.sql
rg -q 'next_retry_at' backend/schema.sql
rg -q 'attempt_count' backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS access_tokens' backend/migrations/0001_platform_initial.sql
rg -q 'CREATE TABLE IF NOT EXISTS password_reset_tokens' backend/migrations/0002_password_reset_tokens.sql
rg -q 'CREATE TABLE IF NOT EXISTS email_distributions' backend/migrations/0003_email_distributions.sql
rg -q 'CREATE TABLE IF NOT EXISTS email_delivery_attempts' backend/migrations/0003_email_distributions.sql
rg -q 'idx_email_distributions_retry_due' backend/migrations/0004_email_delivery_retry.sql
rg -q 'idx_resource_allocations_resource_window' backend/migrations/0005_resource_allocation.sql
rg -q 'idx_resource_profiles_type_status' backend/migrations/0006_resource_profiles.sql
rg -q 'idx_resource_usage_entries_project_date' backend/migrations/0007_resource_usage_cost.sql
rg -q 'idx_project_cost_candidates_project_status' backend/migrations/0007_resource_usage_cost.sql
rg -q 'reviewed_by' backend/migrations/0008_cost_candidate_review.sql backend/schema.sql
rg -q 'idx_project_cost_candidates_reviewed_by' backend/migrations/0008_cost_candidate_review.sql backend/schema.sql
rg -q 'idx_resource_calendar_blocks_resource_window' backend/migrations/0009_resource_calendar_blocks.sql backend/schema.sql
rg -q 'idx_resource_calendar_blocks_project' backend/migrations/0009_resource_calendar_blocks.sql backend/schema.sql
rg -q 'idx_project_cost_handoffs_project_status' backend/migrations/0010_project_cost_handoff.sql backend/schema.sql
rg -q 'idx_project_cost_handoffs_target_status' backend/migrations/0010_project_cost_handoff.sql backend/schema.sql
rg -q 'response_payload' backend/migrations/0011_project_cost_handoff_reconciliation.sql backend/schema.sql
rg -q 'idx_project_cost_handoffs_completed_at' backend/migrations/0011_project_cost_handoff_reconciliation.sql backend/schema.sql
rg -q 'idx_project_cost_handoffs_send_due' backend/migrations/0012_project_cost_handoff_delivery.sql backend/schema.sql
rg -q 'idx_project_cost_handoffs_queued' backend/migrations/0012_project_cost_handoff_delivery.sql backend/schema.sql
rg -q 'CREATE TABLE IF NOT EXISTS project_knowledge_items' backend/migrations/0013_project_knowledge_items.sql
rg -q 'idx_project_knowledge_items_project_kind' backend/migrations/0013_project_knowledge_items.sql
rg -q 'CREATE TABLE IF NOT EXISTS collection_upload_sessions' collection_api/migrations/0001_collection_initial.sql
rg -q 'CREATE TABLE IF NOT EXISTS schema_migrations' scripts/run_migrations.py
rg -q -- '--service platform' scripts/apply_platform_schema.sh
rg -q -- '--service collection' scripts/apply_collection_schema.sh
rg -q 'run_migrations.py' scripts/apply_platform_schema.sh scripts/apply_collection_schema.sh
if rg -q -- '-f schema.sql' scripts/apply_platform_schema.sh scripts/apply_collection_schema.sh docker-compose.yml; then
  echo "Direct schema.sql application must stay disabled; use migrations." >&2
  exit 1
fi
rg -q 'token_type: str = "bearer"' backend/app/schemas.py
rg -q 'require_current_user' backend/app/services/auth_tokens.py backend/app/routers/users.py
rg -q 'require_active_user' backend/app/services/auth_tokens.py backend/app/routers/projects.py backend/app/routers/approvals.py backend/app/routers/dashboard.py backend/app/routers/tasks.py backend/app/routers/resources.py
rg -q 'require_admin_user' backend/app/services/auth_tokens.py backend/app/routers/admin_users.py
rg -q 'prefix="/admin/users"' backend/app/routers/admin_users.py
rg -q 'reset-password' backend/app/routers/admin_users.py web_client/src/main.tsx scripts/smoke_admin_user_registration.sh
rg -q 'UserUpdate' backend/app/schemas.py backend/app/services/users.py backend/app/routers/admin_users.py
rg -q 'admin_password_reset' backend/app/routers/admin_users.py
rg -q 'PasswordResetRequest' backend/app/schemas.py backend/app/routers/users.py
rg -q 'confirm_password_reset' backend/app/services/password_resets.py backend/app/routers/users.py
rg -q 'password_reset_confirmed' backend/app/routers/users.py
rg -q 'dev_token_returned' backend/app/routers/users.py scripts/smoke_password_reset.sh
rg -q 'admin_users' backend/app/main.py
rg -q 'distributions' backend/app/main.py
rg -q 'operations' backend/app/main.py
rg -q 'OperationQueueStatusOut' backend/app/schemas.py backend/app/routers/operations.py
rg -q 'OperationQueueSectionOut' backend/app/schemas.py backend/app/routers/operations.py
rg -q 'queue-status' backend/app/routers/operations.py web_client/src/main.tsx scripts/smoke_operation_queue_status.sh
rg -q 'get_operation_queue_status' backend/app/routers/operations.py
rg -q 'email_distributions' backend/app/routers/operations.py
rg -q 'project_cost_handoffs' backend/app/routers/operations.py
test -x scripts/smoke_overdue_task_risk_promotion.sh
rg -q 'DelayedTaskRiskPromotionOut' backend/app/schemas.py backend/app/routers/tasks.py
rg -q 'promote_overdue_tasks_to_risks' backend/app/routers/tasks.py
rg -q 'promote_overdue_task_to_risk' backend/app/routers/tasks.py scripts/smoke_overdue_task_risk_promotion.sh
rg -q '/tasks/overdue-risks' web_client/src/main.tsx scripts/smoke_overdue_task_risk_promotion.sh
rg -q 'DelayedTaskRiskPromotion' web_client/src/main.tsx
test -x scripts/smoke_cost_candidate_risk_promotion.sh
rg -q 'CostCandidateRiskPromotionOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'promote_cost_candidates_to_risks' backend/app/routers/resources.py
rg -q 'promote_cost_candidate_to_risk' backend/app/routers/resources.py scripts/smoke_cost_candidate_risk_promotion.sh
rg -q '/resources/cost-candidates/overrun-risks' web_client/src/main.tsx scripts/smoke_cost_candidate_risk_promotion.sh
rg -q 'CostCandidateRiskPromotion' web_client/src/main.tsx
test -x scripts/smoke_resource_conflict_risk_promotion.sh
rg -q 'ResourceConflictRiskPromotionOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'promote_resource_conflicts_to_risks' backend/app/routers/resources.py
rg -q 'promote_resource_conflict_to_risk' backend/app/routers/resources.py scripts/smoke_resource_conflict_risk_promotion.sh
rg -q '/resources/allocations/conflict-risks' web_client/src/main.tsx scripts/smoke_resource_conflict_risk_promotion.sh
rg -q 'ResourceConflictRiskPromotion' web_client/src/main.tsx
test -x scripts/smoke_unassigned_resource_demand_risk_promotion.sh
rg -q 'UnassignedResourceDemandRiskPromotionOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'promote_unassigned_resource_demands_to_risks' backend/app/routers/resources.py
rg -q 'promote_unassigned_resource_demand_to_risk' backend/app/routers/resources.py scripts/smoke_unassigned_resource_demand_risk_promotion.sh
rg -q '/resources/demands/unassigned-risks' web_client/src/main.tsx scripts/smoke_unassigned_resource_demand_risk_promotion.sh
rg -q 'UnassignedResourceDemandRiskPromotion' web_client/src/main.tsx
test -x scripts/smoke_resource_usage_overrun_risk_promotion.sh
rg -q 'ResourceUsageOverrunRiskPromotionOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'promote_resource_usage_overruns_to_risks' backend/app/routers/resources.py
rg -q 'promote_resource_usage_overrun_to_risk' backend/app/routers/resources.py scripts/smoke_resource_usage_overrun_risk_promotion.sh
rg -q '/resources/usage/overrun-risks' web_client/src/main.tsx scripts/smoke_resource_usage_overrun_risk_promotion.sh
rg -q 'ResourceUsageOverrunRiskPromotion' web_client/src/main.tsx
rg -q 'EmailDistributionPreviewOut' backend/app/schemas.py backend/app/routers/distributions.py
rg -q 'distribute_meeting_minutes' backend/app/routers/distributions.py
rg -q 'deliver_distribution' backend/app/services/email_delivery.py backend/app/routers/distributions.py
rg -q 'retry_due_distributions' backend/app/routers/distributions.py
rg -q 'dev_log' backend/app/services/email_delivery.py scripts/smoke_email_distribution.sh scripts/smoke_email_retry.sh
rg -q '/distributions/retry-due' scripts/smoke_email_retry.sh
rg -q '/distributions/retry-due' web_client/src/main.tsx
rg -q '/distributions/retry-due' scripts/smoke_operation_queue_status.sh
rg -q 'run_email_delivery_worker_once' README.md docs/15_mvp_first_implementation.md scripts/run_email_delivery_worker_once.sh
test -x scripts/smoke_web_public_binding_guard.sh
test -x scripts/smoke_apk_publication_freshness.sh
rg -q 'AIPMS_WEB_ALLOW_PUBLIC_BIND' scripts/run_local_execution_stack.sh scripts/run_public_tunnels.sh scripts/windows_web_dev.ps1 scripts/windows_run_web_client.ps1 README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md web_client/README.md
rg -q 'WEB_BIND_HOST="\$\{AIPMS_WEB_BIND_HOST:-127\.0\.0\.1\}"' scripts/run_local_execution_stack.sh scripts/run_public_tunnels.sh
rg -q 'smoke_apk_publication_freshness' scripts/run_continuous_acceptance_check.sh scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
if rg -q '&& exec cd web_client' scripts/run_local_execution_stack.sh; then
  echo "local execution stack must support compound Web commands." >&2
  exit 1
fi
rg -q 'ResourceAllocationCreate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ResourceProfileCreate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ResourceCalendarBlockCreate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ResourceCalendarBlockOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ResourceUsageCreate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ProjectCostCandidateOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ProjectCostCandidateStatusUpdate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ProjectCostHandoffCreate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ProjectCostHandoffSendDueRequest' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ProjectCostHandoffStatusUpdate' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'ProjectCostHandoffOut' backend/app/schemas.py backend/app/routers/resources.py
rg -q 'resource_usage_entries' backend/app/routers/dashboard.py web_client/src/main.tsx
rg -q 'cost_candidates' backend/app/routers/dashboard.py web_client/src/main.tsx
test -x scripts/smoke_dashboard_attention_kpis.sh
rg -q 'DashboardSummaryOut' backend/app/schemas.py backend/app/routers/dashboard.py
rg -q 'overdue_tasks' backend/app/routers/dashboard.py web_client/src/main.tsx scripts/smoke_dashboard_attention_kpis.sh
rg -q 'unresolved_risks' backend/app/routers/dashboard.py web_client/src/main.tsx scripts/smoke_dashboard_attention_kpis.sh
rg -q 'resource_conflicts' backend/app/routers/dashboard.py web_client/src/main.tsx scripts/smoke_dashboard_attention_kpis.sh
rg -q 'distribution_failures' backend/app/routers/dashboard.py web_client/src/main.tsx scripts/smoke_dashboard_attention_kpis.sh
rg -q 'Attention KPI' web_client/src/main.tsx
rg -q 'attention-row' web_client/src/main.tsx web_client/src/styles.css
rg -q 'create_resource_allocation' backend/app/routers/resources.py
rg -q 'record_resource_usage' backend/app/routers/resources.py
rg -q 'review_project_cost_candidate' backend/app/routers/resources.py
rg -q 'Cost candidate review role required' backend/app/routers/resources.py
rg -q 'create_project_cost_handoff' backend/app/routers/resources.py
rg -q 'deliver_project_cost_handoff' backend/app/services/erp_handoff.py backend/app/routers/resources.py scripts/run_erp_handoff_worker_once.sh
rg -q 'send_due_project_cost_handoffs' backend/app/routers/resources.py
rg -q '/resources/cost-handoffs/send-due' web_client/src/main.tsx
rg -q '/resources/cost-handoffs/send-due' scripts/smoke_operation_queue_status.sh
rg -q 'send_project_cost_handoff' backend/app/routers/resources.py backend/app/services/erp_handoff.py
rg -q 'ERP handoff endpoint URL is not configured' backend/app/services/erp_handoff.py scripts/smoke_erp_handoff_delivery.sh
rg -q 'reconcile_project_cost_handoff' backend/app/routers/resources.py
rg -q 'Completed cost handoff cannot be changed' backend/app/routers/resources.py
rg -q 'ERP handoff role required' backend/app/routers/resources.py
rg -q 'external_erp_reference_only' backend/app/routers/resources.py scripts/smoke_resource_usage_cost.sh
rg -q 'run_erp_handoff_worker_once' README.md docs/15_mvp_first_implementation.md scripts/run_erp_handoff_worker_once.sh
test -x scripts/smoke_project_knowledge_index.sh
rg -q 'ProjectKnowledgeItemOut' backend/app/schemas.py backend/app/routers/projects.py
rg -q 'index_approved_meeting_analysis' backend/app/services/knowledge_index.py backend/app/routers/approvals.py
rg -q 'created_knowledge_items' backend/app/routers/approvals.py scripts/smoke_project_knowledge_index.sh
rg -q 'tags::text ILIKE' backend/app/routers/projects.py
rg -q 'evidence_refs::text ILIKE' backend/app/routers/projects.py
rg -q 'params=.*\"q\"' scripts/smoke_project_knowledge_index.sh
rg -q 'project_knowledge_items' backend/app/routers/dashboard.py backend/app/routers/projects.py scripts/smoke_project_knowledge_index.sh
rg -q 'knowledge_items' backend/app/routers/dashboard.py backend/app/routers/projects.py web_client/src/main.tsx
rg -q '지식 항목' web_client/src/main.tsx
rg -q 'ProjectKnowledgeItem' web_client/src/main.tsx
rg -q 'loadKnowledgeItems' web_client/src/main.tsx
rg -q '/knowledge-items' web_client/src/main.tsx
rg -q 'Project Knowledge' web_client/src/main.tsx
rg -q 'knowledgeSearchTerm' web_client/src/main.tsx
rg -q 'formatEvidenceRef' web_client/src/main.tsx
rg -q 'knowledge-toolbar' web_client/src/main.tsx web_client/src/styles.css
rg -q 'knowledge-row' web_client/src/main.tsx web_client/src/styles.css
rg -q 'knowledge-evidence' web_client/src/main.tsx web_client/src/styles.css
rg -q 'smoke_project_knowledge_index' README.md docs/15_mvp_first_implementation.md scripts/verify_mvp_static.sh
test -x scripts/run_operations_recovery_once.sh
test -x scripts/install_launchd_operations_recovery.sh
rg -q 'run_email_delivery_worker_once' scripts/run_operations_recovery_once.sh
rg -q 'run_erp_handoff_worker_once' scripts/run_operations_recovery_once.sh
rg -q 'run_operations_recovery_once' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'install_launchd_operations_recovery' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'StartInterval' scripts/install_launchd_operations_recovery.sh
rg -q 'AIPMS_OPERATIONS_RECOVERY_INTERVAL_SECONDS' scripts/install_launchd_operations_recovery.sh
rg -q 'create_resource_calendar_block' backend/app/routers/resources.py
rg -q 'blocking_calendar_block_id' backend/app/schemas.py backend/app/routers/resources.py web_client/src/main.tsx
rg -q 'Resource calendar manager role required' backend/app/routers/resources.py
rg -q 'list_resource_profile_availability' backend/app/routers/resources.py
rg -q 'resource_allocations' scripts/smoke_resource_allocation.sh docs/13_required_resource_demand_policy.md
rg -q 'resource_profiles' scripts/smoke_resource_profiles.sh docs/13_required_resource_demand_policy.md
rg -q 'resource_calendar_blocks' scripts/smoke_resource_calendar_blocks.sh docs/13_required_resource_demand_policy.md
rg -q 'resource_usage_entries' scripts/smoke_resource_usage_cost.sh docs/13_required_resource_demand_policy.md
rg -q 'project_cost_candidates' scripts/smoke_resource_usage_cost.sh docs/13_required_resource_demand_policy.md
rg -q 'project_cost_handoffs' scripts/smoke_resource_usage_cost.sh docs/13_required_resource_demand_policy.md
rg -q 'create_user_record' backend/app/services/users.py backend/app/routers/admin_users.py scripts/seed_platform_user.py
rg -F -q 'public_create.status_code in {404, 405}' scripts/smoke_admin_user_registration.sh scripts/smoke_auth_tokens.sh scripts/smoke_protected_platform_api.sh
if rg -F -q '@router.post("")' backend/app/routers/users.py || rg -F -q '@router.get("")' backend/app/routers/users.py; then
  echo "Public /users collection route must stay disabled; use /admin/users." >&2
  exit 1
fi
rg -q 'X-Collection-Key-Id' backend/app/routers/collection_callbacks.py collection_api/app/routers/collection.py
rg -q 'PLATFORM_CALLBACK_SECRET_ID' collection_api/.env.example
rg -q 'usesCleartextTraffic' android_client/src/main/AndroidManifest.xml
rg -q 'AIPMS_PLATFORM_BASE_URL' android_client/build.gradle.kts android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'AIPMS_COLLECTION_BASE_URL' android_client/build.gradle.kts android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'aipmsPlatformBaseUrl' android_client/build.gradle.kts scripts/build_android_lan_debug.sh
rg -q 'install_android_physical_lan_debug' README.md android_client/README.md docs/15_mvp_first_implementation.md
test -x scripts/install_android_public_debug_apk.sh
test -x scripts/collect_public_review_responses.sh
rg -q 'install_android_public_debug_apk' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md
rg -q 'collect_public_review_responses' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md scripts/publish_public_review_package.sh
rg -q 'public_review_response_summary' scripts/collect_public_review_responses.sh
rg -q 'runtime/review_responses/inbox' README.md docs/09_kim_heeseop_work_structure.md docs/18_part_handoff_drafts.md scripts/collect_public_review_responses.sh scripts/publish_public_review_package.sh
rg -q 'latest_summary.json' docs/09_kim_heeseop_work_structure.md scripts/collect_public_review_responses.sh scripts/publish_public_review_package.sh
rg -q 'AIPMS_ANDROID_INSTALL_DRY_RUN' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/install_android_public_debug_apk.sh
rg -q 'AIPMS_ALLOW_EMULATOR' docs/09_kim_heeseop_work_structure.md scripts/install_android_public_debug_apk.sh
rg -q 'android_public_apk_install_check' scripts/install_android_public_debug_apk.sh
rg -q 'AiPmsAndroidClient-responsive-public-debug.apk' scripts/install_android_public_debug_apk.sh docs/09_kim_heeseop_work_structure.md
rg -q 'AI-PMS-Recorder.apk' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md scripts/build_android_public_debug.sh scripts/publish_android_apk_download.sh scripts/smoke_public_access.sh
rg -q 'pm grant.*RECORD_AUDIO' scripts/install_android_public_debug_apk.sh
rg -q 'smoke_lan_access' README.md android_client/README.md docs/15_mvp_first_implementation.md
test -x scripts/run_public_tunnels.sh
test -x scripts/print_public_urls.sh
test -x scripts/smoke_public_access.sh
test -x scripts/build_android_public_debug.sh
test -x scripts/publish_android_apk_download.sh
test -x scripts/publish_public_execution_hub.sh
test -x scripts/run_local_execution_stack.sh
test -x scripts/prepare_cloudflare_named_tunnel.sh
test -x scripts/run_cloudflare_named_tunnel.sh
test -x scripts/prepare_android_release_signing.sh
test -x scripts/build_android_release_apk.sh
test -x scripts/smoke_android_release_readiness.sh
test -x scripts/export_formal_requirements_definition.py
test -x scripts/smoke_formal_requirements_definition.sh
test -x scripts/publish_requirements_documents.sh
test -x scripts/smoke_requirements_publication.sh
test -x scripts/export_portfolio_evidence_bundle.sh
test -x scripts/smoke_portfolio_evidence_bundle.sh
test -x scripts/doctor_local_environment.sh
test -x scripts/smoke_local_environment_doctor.sh
test -x scripts/repair_web_dependencies.sh
test -x scripts/smoke_collection_public_binding_guard.sh
test -x scripts/smoke_core_api_public_binding_guard.sh
test -x scripts/run_continuous_acceptance_check.sh
test -x scripts/doctor_public_handoff.sh
test -x scripts/smoke_public_handoff_doctor.sh
test -x scripts/seed_demo_admin.sh
test -x scripts/smoke_demo_admin_credentials.sh
test -x scripts/publish_public_review_package.sh
test -x scripts/refresh_public_handoff_bundle.sh
rg -q 'run_public_tunnels' README.md android_client/README.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md
rg -q 'AIPMS_PUBLIC_TUNNEL_REUSE_HEALTH_CHECK' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/run_public_tunnels.sh
rg -q 'public_tunnel_healthy' scripts/run_public_tunnels.sh
rg -q 'grep -aEo' scripts/run_public_tunnels.sh scripts/print_public_urls.sh scripts/smoke_public_access.sh scripts/build_android_public_debug.sh scripts/build_android_release_apk.sh scripts/publish_public_review_package.sh scripts/publish_public_execution_hub.sh
rg -q 'smoke_public_access' README.md android_client/README.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md
rg -q 'build_android_public_debug' README.md android_client/README.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md
rg -q 'publish_android_apk_download' README.md android_client/README.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md scripts/build_android_public_debug.sh
rg -q 'publish_public_execution_hub' docs/09_kim_heeseop_work_structure.md scripts/refresh_public_handoff_bundle.sh
rg -q 'run_local_execution_stack' README.md web_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'AIPMS_LOCAL_STACK_REUSE_HEALTH_CHECK' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/run_local_execution_stack.sh
rg -q 'local_http_ok' scripts/run_local_execution_stack.sh
rg -q 'public_execution_hub' scripts/publish_public_execution_hub.sh
rg -q 'web_client/public/run/index.html' docs/09_kim_heeseop_work_structure.md scripts/publish_public_execution_hub.sh
rg -q '/run/execution.json' README.md android_client/README.md scripts/publish_public_execution_hub.sh
rg -q 'MEETFLOW' web_client/src/main.tsx web_client/public/downloads/index.html scripts/publish_android_apk_download.sh scripts/publish_public_execution_hub.sh
rg -q 'PublicRunPage' web_client/src/main.tsx scripts/smoke_public_access.sh
rg -q 'usePublicExecutionManifest' web_client/src/main.tsx scripts/smoke_public_access.sh
rg -q 'PublicExecutionManifest' web_client/src/main.tsx
rg -q 'React public routes' README.md web_client/README.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md
rg -q 'execution_hub_url' scripts/refresh_public_handoff_bundle.sh
rg -q 'publish_public_review_package' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md
rg -q 'refresh_public_handoff_bundle' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md scripts/publish_public_review_package.sh
rg -q 'AIPMS_REFRESH_BUILD_APK' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md scripts/refresh_public_handoff_bundle.sh
rg -q 'public_handoff_refresh_summary' scripts/refresh_public_handoff_bundle.sh
rg -q 'prepare_cloudflare_named_tunnel' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md docs/19_cloudflare_named_tunnel_plan.md
rg -q 'run_cloudflare_named_tunnel' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md docs/19_cloudflare_named_tunnel_plan.md
rg -q 'AIPMS_CF_TUNNEL_ID' scripts/prepare_cloudflare_named_tunnel.sh docs/19_cloudflare_named_tunnel_plan.md
rg -q 'runtime/cloudflare_named_tunnel/config.yml' scripts/run_cloudflare_named_tunnel.sh docs/15_mvp_first_implementation.md docs/19_cloudflare_named_tunnel_plan.md
rg -q 'Cloudflare named tunnel' docs/08_drive_based_reconfiguration.md docs/19_cloudflare_named_tunnel_plan.md
rg -q 'AIPMS_RELEASE_STORE_FILE' android_client/build.gradle.kts scripts/prepare_android_release_signing.sh scripts/build_android_release_apk.sh docs/20_android_release_signing.md android_client/README.md
rg -q 'AIPMS_RELEASE_KEY_ALIAS' android_client/build.gradle.kts scripts/prepare_android_release_signing.sh scripts/build_android_release_apk.sh docs/20_android_release_signing.md
rg -q 'assembleRelease' scripts/build_android_release_apk.sh docs/09_kim_heeseop_work_structure.md
rg -q 'AiPmsAndroidClient-responsive-release.apk' scripts/build_android_release_apk.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/20_android_release_signing.md
rg -q 'prepare_android_release_signing' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md docs/20_android_release_signing.md
rg -q 'build_android_release_apk' README.md android_client/README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md docs/20_android_release_signing.md
rg -q 'smoke_android_release_readiness' scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md docs/20_android_release_signing.md
rg -q 'smoke_formal_requirements_definition' scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'AI-PMS 기반 회의·업무·지식 통합관리 플랫폼 요구사항 정의서_v0.2.docx' scripts/export_formal_requirements_definition.py docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/16_drive_source_inventory.md
rg -q 'smoke_requirements_publication' scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'AI-PMS-requirements-v0.2.docx' scripts/publish_requirements_documents.sh scripts/publish_public_review_package.sh scripts/publish_public_execution_hub.sh scripts/smoke_public_access.sh
rg -q 'requirements_docx' scripts/publish_public_review_package.sh scripts/publish_public_execution_hub.sh scripts/smoke_public_access.sh
rg -q 'smoke_portfolio_evidence_bundle' scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'AI_PMS_MVP_실행검증_포트폴리오.md' scripts/export_portfolio_evidence_bundle.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/16_drive_source_inventory.md
rg -q 'metadata_match' scripts/smoke_portfolio_evidence_bundle.sh runtime/portfolio_evidence/latest_portfolio_evidence.json
rg -q 'local_environment_doctor' scripts/doctor_local_environment.sh scripts/smoke_local_environment_doctor.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'latest_doctor.json' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/doctor_local_environment.sh
rg -q 'latest_doctor.md' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/doctor_local_environment.sh
rg -q 'AIPMS_LOCAL_ENV_DOCTOR_STRICT' scripts/doctor_local_environment.sh
rg -q 'smoke_local_environment_doctor' scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md
rg -q 'repair_web_dependencies' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/repair_web_dependencies.sh scripts/doctor_local_environment.sh
rg -q 'run_continuous_acceptance_check' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/run_continuous_acceptance_check.sh scripts/verify_mvp_static.sh
rg -q 'smoke_core_api_public_binding_guard' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/run_continuous_acceptance_check.sh scripts/verify_mvp_static.sh
rg -q 'AIPMS_PLATFORM_ALLOW_PUBLIC_BIND' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/run_platform_backend.sh scripts/windows_run_platform_backend.ps1 backend/.env.example
rg -q 'AIPMS_ANALYSIS_ALLOW_PUBLIC_BIND' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md scripts/run_analysis_server.sh scripts/windows_run_analysis_server.ps1 analysis_server/.env.example
rg -q 'public_handoff_doctor' scripts/doctor_public_handoff.sh scripts/smoke_public_handoff_doctor.sh docs/09_kim_heeseop_work_structure.md
rg -q 'latest_doctor.json' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/16_drive_source_inventory.md scripts/doctor_public_handoff.sh
rg -q 'latest_doctor.md' README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/16_drive_source_inventory.md scripts/doctor_public_handoff.sh
rg -q 'AIPMS_PUBLIC_HANDOFF_DOCTOR_STRICT' scripts/doctor_public_handoff.sh docs/09_kim_heeseop_work_structure.md
rg -q 'smoke_public_handoff_doctor' scripts/verify_mvp_static.sh docs/09_kim_heeseop_work_structure.md
rg -q 'trycloudflare' backend/app/main.py web_client/vite.config.ts scripts/run_public_tunnels.sh scripts/smoke_public_access.sh
rg -q 'AIPMS_PUBLIC_PLATFORM_URL' scripts/build_android_public_debug.sh scripts/smoke_public_access.sh
rg -q 'Web APK download route' scripts/smoke_public_access.sh
rg -q 'Web execution hub' scripts/smoke_public_access.sh
rg -q 'Web execution JSON' scripts/smoke_public_access.sh
rg -q 'Web APK install guide' scripts/smoke_public_access.sh
rg -q 'Web handoff route' scripts/smoke_public_access.sh
rg -q 'Web handoff static' scripts/smoke_public_access.sh
rg -q 'Web review package' scripts/smoke_public_access.sh
rg -q 'Web APK file' scripts/smoke_public_access.sh
rg -q 'install.html' scripts/publish_android_apk_download.sh scripts/publish_public_review_package.sh scripts/smoke_public_access.sh README.md android_client/README.md docs/18_part_handoff_drafts.md
rg -q 'AI-PMS Recorder 설치 확인' scripts/publish_android_apk_download.sh
rg -q '휴대폰 / 태블릿' scripts/publish_android_apk_download.sh scripts/smoke_public_access.sh
rg -q 'apk_install_guide' scripts/publish_public_review_package.sh scripts/smoke_public_access.sh
rg -q 'public-review-package.json' scripts/publish_public_review_package.sh scripts/smoke_public_access.sh web_client/public/handoff/index.html docs/18_part_handoff_drafts.md
rg -q 'review-response-template.md' scripts/publish_public_review_package.sh scripts/smoke_public_access.sh scripts/refresh_public_handoff_bundle.sh web_client/public/handoff/index.html README.md docs/18_part_handoff_drafts.md
rg -q 'AI-PMS 파트별 검토 회신 템플릿' scripts/publish_public_review_package.sh
rg -q '승인 가능 / 수정 필요 / 질문 / 미검증' scripts/publish_public_review_package.sh scripts/smoke_public_access.sh
rg -q 'response_template' scripts/publish_public_review_package.sh scripts/smoke_public_access.sh scripts/refresh_public_handoff_bundle.sh
rg -q 'response_collection' scripts/publish_public_review_package.sh scripts/smoke_public_access.sh scripts/refresh_public_handoff_bundle.sh
rg -q 'public_review_package' scripts/smoke_public_access.sh web_client/public/handoff/public-review-package.json
rg -q 'handoff_static' scripts/smoke_public_access.sh
rg -q 'review_scopes' scripts/smoke_public_access.sh web_client/public/handoff/public-review-package.json
rg -q 'responsive_phone_tablet' scripts/smoke_public_access.sh
rg -q 'apk_alias' scripts/publish_android_apk_download.sh scripts/smoke_public_access.sh scripts/publish_public_execution_hub.sh scripts/publish_public_review_package.sh
rg -q 'Web APK alias file' scripts/smoke_public_access.sh
rg -q 'responsive_phone_tablet' web_client/public/downloads/android-apk.json
for file in README.md docs/09_kim_heeseop_work_structure.md docs/15_mvp_first_implementation.md docs/18_part_handoff_drafts.md; do
  rg -q 'public download and handoff' "$file"
done
rg -q 'AiPmsAndroidClient-responsive-public-debug.apk' scripts/build_android_public_debug.sh scripts/publish_android_apk_download.sh docs/18_part_handoff_drafts.md
rg -q 'android-apk.json' scripts/publish_android_apk_download.sh docs/09_kim_heeseop_work_structure.md
rg -q 'APK 다운로드' web_client/public/downloads/index.html docs/18_part_handoff_drafts.md
rg -q 'MEETFLOW APK' web_client/public/downloads/index.html scripts/publish_android_apk_download.sh
test -f web_client/public/downloads/install.html
rg -q 'APK_DOWNLOAD_PATH' web_client/src/main.tsx
rg -q 'APK 다운로드' web_client/src/main.tsx docs/18_part_handoff_drafts.md
rg -q 'download-link' web_client/src/main.tsx web_client/src/styles.css
rg -q 'PublicHandoffPage' web_client/src/main.tsx
rg -q 'PublicDownloadPage' web_client/src/main.tsx
rg -q 'AI-PMS 화면 확인' web_client/src/main.tsx web_client/public/handoff/index.html
rg -q '앱·웹 통합 확인' web_client/src/main.tsx web_client/public/handoff/index.html
rg -q '업로드.*상태 확인' web_client/src/main.tsx web_client/public/handoff/index.html
rg -q 'AiPmsAndroidClient-responsive-public-debug.apk' web_client/public/handoff/index.html
rg -q 'public-flow' web_client/src/main.tsx web_client/src/styles.css
rg -q 'public-hero' web_client/src/main.tsx web_client/src/styles.css
test -f web_client/public/handoff/index.html
test -f web_client/public/handoff/public-review-package.json
test -f web_client/public/handoff/review-response-template.md
test -f web_client/public/downloads/AiPmsAndroidClient-responsive-public-debug.apk
test -f web_client/public/downloads/android-apk.json
rg -q 'resizeableActivity' android_client/src/main/AndroidManifest.xml
rg -q 'screenWidthDp >= 600' android_client/src/main/java/com/aipms/MainActivity.kt docs/09_kim_heeseop_work_structure.md
rg -q 'MediaRecorder' android_client/src/main/java/com/aipms/recording/AndroidAudioRecorder.kt
rg -q 'getProjectDetail' android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt
rg -q 'getMeetingStatus' android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt
rg -q 'MeetingStatusDto' android_client/src/main/java/com/aipms/client/AiPmsContracts.kt android_client/src/main/java/com/aipms/MainActivity.kt
rg -q '처리상태 확인' android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'screenDesignTraceMarkers' android_client/src/main/java/com/aipms/MainActivity.kt
rg -F -q 'recordButton = button("녹음 시작")' android_client/src/main/java/com/aipms/MainActivity.kt
rg -F -q 'contentHost.addView(homeScreen())' android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'Android client does not include attendee-save API contracts' android_client/README.md scripts/smoke_screen_design_ui.sh
for forbidden in \
  'replaceMeetingAttendees' \
  'MeetingAttendeesReplaceRequest' \
  'MeetingAttendeeDto' \
  'attendee_user_ids' \
  '/attendees' \
  'CheckBox'
do
  if rg -F -q "$forbidden" android_client/src/main/java; then
    echo "Android active upload flow must not expose manual attendee selection or attendee-save API: $forbidden" >&2
    exit 1
  fi
done
if rg -q '직접 참석자|참석자 저장|참석자를 선택|attendee-save' android_client/src/main/java/com/aipms; then
  echo "Android active upload flow must stay project-only for meeting recording." >&2
  exit 1
fi
rg -q 'LoginRequest' android_client/src/main/java/com/aipms/client/AiPmsContracts.kt android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'PasswordChangeRequest' android_client/src/main/java/com/aipms/client/AiPmsContracts.kt android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'Authorization' android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt
rg -q 'getMe' android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt
rg -q 'SharedPreferences\\|getSharedPreferences' android_client/src/main/java/com/aipms/MainActivity.kt
rg -q 'submitFormWithBinaryData' android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt
rg -q 'X-Upload-Token' android_client/src/main/java/com/aipms/client/KtorAiPmsApiClient.kt
rg -q 'AUTH_STORAGE_KEY' web_client/src/main.tsx
rg -q '/users/login' web_client/src/main.tsx
rg -q '/users/me' web_client/src/main.tsx
rg -q '/users/logout' web_client/src/main.tsx
rg -q '/users/password/change' web_client/src/main.tsx
rg -q '/users/password-reset/request' web_client/src/main.tsx
rg -q '/users/password-reset/confirm' web_client/src/main.tsx
rg -q '비밀번호 찾기' web_client/src/main.tsx
rg -q '/admin/users' web_client/src/main.tsx
rg -q 'AdminUsersPanel' web_client/src/main.tsx
rg -q 'activeView === "admin"' web_client/src/main.tsx
rg -q 'recentMeetings' web_client/src/main.tsx
rg -q '최근 회의 처리 상태' web_client/src/main.tsx
rg -q 'resourceUsage' web_client/src/main.tsx
rg -q 'costCandidates' web_client/src/main.tsx
rg -q 'formatLocalDate' web_client/src/main.tsx
rg -q 'calendar block' web_client/src/main.tsx
rg -q 'Cost Feedback' web_client/src/main.tsx
rg -q 'Operations Queue' web_client/src/main.tsx
rg -q 'OperationQueueStatus' web_client/src/main.tsx
rg -q 'ops-card' web_client/src/main.tsx web_client/src/styles.css
rg -q 'runEmailRetryDue' web_client/src/main.tsx
rg -q 'runErpHandoffSendDue' web_client/src/main.tsx
rg -q 'ops-actions' web_client/src/main.tsx
rg -q 'ops-actions' web_client/src/styles.css
rg -q '/resources/cost-candidates' web_client/src/main.tsx
rg -q 'onReviewCostCandidate' web_client/src/main.tsx
rg -q '비용 후보 승인' web_client/src/main.tsx
rg -q 'icon-button\.approve' web_client/src/styles.css
rg -q '/distribution-preview' web_client/src/main.tsx
rg -q '/distribute' web_client/src/main.tsx
rg -q 'DistributionPanel' web_client/src/main.tsx
rg -q '배포 미리보기' web_client/src/main.tsx
rg -q 'createUploadSession' android_client/src/main/java/com/aipms/client/MeetingUploadRepository.kt
rg -q 'createAnalysisJob' android_client/src/main/java/com/aipms/client/MeetingUploadRepository.kt
rg -q 'RECORD_AUDIO' android_client/src/main/AndroidManifest.xml android_client/src/main/java/com/aipms/MainActivity.kt

if [[ -x /opt/homebrew/opt/openjdk@21/bin/java && -x android_client/gradlew ]]; then
  bash scripts/build_android_debug.sh
else
  echo "Android Gradle verification skipped: JDK and/or Gradle wrapper unavailable"
fi

echo "AI-PMS MVP static verification passed"

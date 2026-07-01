# Vibe Coding Connectivity Guide

Use this guide during AI coding sessions to strengthen connectivity without
changing the intended service boundaries. Use
`docs/27_lan_connectivity_runbook.md` for the operational runbook.
Use `docs/29_analysis_failover_topology.md` when adding a second PC as a backup
analysis node. Use `scripts/doctor_cross_server_connectivity.sh` to verify the
current primary/secondary server split before changing client code.

## Goal

The app and Web client should use only the Mac mini public-facing APIs.

```text
Android app / Web
  -> Platform API: http://<Mac-mini-LAN-IP>:8000
  -> Collection API: http://<Mac-mini-LAN-IP>:8200
      -> Analysis Worker pulls jobs on the Mac mini
      -> Collection callback writes analysis results to Platform
```

The Analysis server on `8100` is not a direct app/Web target. Use direct
access only for health checks, manual debugging, or Swagger inspection.

## Architecture Rules

- Keep client-facing endpoints limited to Platform `8000` and Collection `8200`.
- Do not add direct Android/Web calls to Analysis `8100`.
- Keep upload state in Collection.
- Keep meeting, approval, review, distribution, and PMS state in Platform.
- Keep STT/LLM processing in the Mac mini worker.
- Treat LLM output as draft data until Platform review/approval confirms it.
- Prefer scripts and docs for connectivity fixes before changing app or API contracts.

## Preferred Change Order

1. Confirm the target LAN IP.

   ```bash
   ipconfig getifaddr en0
   ```

2. Start the LAN stack on the Mac mini.

   ```bash
   cd ai_pms_bootstrap
   bash scripts/run_lan_execution_stack.sh
   ```

3. Run the connectivity doctor.

   ```bash
   bash scripts/doctor_lan_connectivity.sh
   ```

4. Build Android against the same Mac mini IP.

   ```bash
   LAN_IP=<Mac-mini-LAN-IP> bash scripts/build_android_lan_debug.sh
   ```

5. Only change code if a required doctor check fails for a reason that scripts or
   environment variables cannot solve.

## Coding Guardrails

Do:

- Use `AIPMS_PLATFORM_BIND_HOST=0.0.0.0` with
  `AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1` only for intentional LAN testing.
- Use `AIPMS_COLLECTION_BIND_HOST=0.0.0.0` with
  `AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1` only for intentional LAN testing.
- Keep Android build-time URLs injected through `aipmsPlatformBaseUrl` and
  `aipmsCollectionBaseUrl`.
- Keep Web runtime API URL controlled by `VITE_API_BASE`.
- Use `scripts/doctor_lan_connectivity.sh` as the acceptance check for LAN work.
- Document any new run/debug path in `docs/27_lan_connectivity_runbook.md`.

Do not:

- Hard-code a personal LAN IP in source files.
- Change app code to call `http://<Mac-mini-LAN-IP>:8100`.
- Expose secrets in docs, logs, APK metadata, or public handoff files.
- Disable auth to make connectivity tests pass.
- Treat ping success as API success; TCP and HTTP health checks must pass.
- Bind APIs to `0.0.0.0` by default without the explicit allow variables.

## Acceptance Criteria

A LAN connectivity change is acceptable when:

- `scripts/doctor_lan_connectivity.sh` reports required checks passing on the Mac mini.
- PC or phone can open `http://<Mac-mini-LAN-IP>:8000/health`.
- PC or phone can open `http://<Mac-mini-LAN-IP>:8200/health`.
- Web uses `VITE_API_BASE=http://<Mac-mini-LAN-IP>:8000`.
- Android APK is built with:

  ```bash
  LAN_IP=<Mac-mini-LAN-IP> bash scripts/build_android_lan_debug.sh
  ```

- Upload creates a Collection job.
- Worker completes the job or reports a clear failure.
- Platform receives or can replay the Collection callback.
- Web/App can read the latest meeting status from Platform.

## Troubleshooting Map

| Symptom | Likely Cause | First Check |
|---|---|---|
| Ping works, `8000` fails | Platform is stopped, local-only, or blocked | `bash scripts/doctor_lan_connectivity.sh` |
| Ping works, `8200` fails | Collection is stopped, local-only, or blocked | `bash scripts/doctor_lan_connectivity.sh` |
| Upload starts but analysis never finishes | Worker loop stopped or Collection URL wrong | `runtime/lan_execution/aipms-worker.log` |
| Job completes but Web shows no result | Platform callback failed | Collection job events and callback retry status |
| Web opens but login/API fails | `VITE_API_BASE` points to the wrong host | Browser network panel and Web startup command |
| Android app cannot connect | APK was built with old URLs | Rebuild with `LAN_IP=<Mac-mini-LAN-IP>` |
| `8100` fails from PC/phone | Usually acceptable | Use worker flow unless debugging Analysis directly |

## Prompt For Future AI Sessions

Use this prompt when asking an AI coding agent to continue this work:

```text
Follow docs/28_vibe_coding_connectivity_guide.md.
Preserve the flow: App/Web -> Platform 8000 + Collection 8200 -> Mac mini worker -> Platform callback.
Do not make Android/Web call Analysis 8100 directly.
Prefer scripts/docs/env wiring over API contract changes.
Validate with scripts/doctor_lan_connectivity.sh and summarize required failures.
```

## Rollback

Connectivity guide changes are documentation/script-level. If a change causes
confusion, revert the latest guide/script files and return to the manual startup
commands in `docs/27_lan_connectivity_runbook.md`.

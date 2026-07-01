# Analysis Failover Topology

This guide describes how to use another PC as a backup or cross-server analysis
node without breaking the intended app/Web flow.

## Decision

Use one primary Platform server as the source of truth. The first safe
cross-server mode is:

```text
Mac mini or primary PC:
  Platform API
  Platform database
  primary Collection queue
  Web and APK publication

Second PC:
  secondary Collection/Analysis runtime or worker-capable node
  unique WORKER_ID
  no independent Platform authority
```

Do not run two independent Platform databases for the same project data. That
creates split meeting status, approval, distribution, task, and risk state.

## Current LAN Addresses

Observed on this workspace session:

```text
This Windows PC Wi-Fi IP: 192.168.219.100
Mac mini expected IP:     192.168.219.102
```

Current observed state from this Windows PC:

```text
192.168.219.100:8000 closed
192.168.219.100:8100 closed
192.168.219.100:8200 closed
192.168.219.100:3000 closed

192.168.219.102:8000 closed
192.168.219.102:8100 closed
192.168.219.102:8200 closed
```

IPs can change after Wi-Fi reconnects. Re-check before building APKs or sharing
URLs.

Mac mini:

```bash
ipconfig getifaddr en0
```

Windows:

```powershell
Get-NetIPAddress -AddressFamily IPv4
```

## Stable Product Flow

Keep the client flow stable:

```text
Android app / Web
  -> Platform API on the primary host: 8000
  -> Collection API on the selected collection host: 8200
      -> analysis worker processes queued jobs
      -> Collection sends Platform callback
  -> App/Web reads status and results from Platform
```

Do not make Android or Web call Analysis `8100` directly.

## Recommended Failover Level

Use worker redundancy first.

The safest near-term target is:

```text
Primary host, usually Mac mini:
  Platform API: 8000
  Collection API: 8200
  PostgreSQL
  Analysis worker enabled

Backup analysis PC:
  Analysis/worker process
  Unique WORKER_ID
  Same model/runtime family where possible
```

Only one Platform should own PMS state. Do not split approvals, meetings,
tasks, or distributions across two independent Platform databases.

## Cross-Server Modes

| Mode | Status | Use When | Notes |
|---|---|---|---|
| PC as Web/App client only | Safe now | Review, demo, external access | Use current public URLs or LAN URLs |
| PC as secondary Analysis/Collection runtime | Safe with shared DB/storage | Extra STT/LLM capacity or failover | Requires shared Collection DB and audio storage |
| PC as full Platform backup | Not MVP-safe | Disaster recovery only | Requires DB replication and failover plan |
| Active-active Platform | Not allowed | None for MVP | Causes state conflicts |

## Important Storage Warning

Audio jobs reference stored files. A backup worker can process audio only if it
can access the same audio storage as the Collection service that accepted the
upload.

Acceptable options:

- Keep Collection and worker on the same host.
- Put `storage/audio` on a shared SMB/NAS/Drive path visible to all workers.
- Add a future Collection file-download endpoint and make remote workers fetch
  audio over HTTP before STT.

Without shared audio access, the backup node may work for transcript-only jobs
but fail for uploaded audio jobs.

## Current Public Primary URLs

When the public runtime watchdog is active, the latest URL set is written to:

```text
~/.aipms/public-runtime-state/runtime/always_on/latest_public_runtime.json
```

Current verified public roles on 2026-07-01:

```text
Web:        https://ips-owner-bin-craps.trycloudflare.com
Platform:   https://tap-inform-bookstore-disposition.trycloudflare.com
Collection: https://broadway-gateway-potato-forwarding.trycloudflare.com
Analysis:   https://totally-tones-ending-axis.trycloudflare.com
```

Quick `trycloudflare.com` URLs are not permanent. Use Cloudflare named tunnel
and DNS before relying on them as fixed cross-server endpoints.

## Server URLs To Use

If the Mac mini is primary:

```text
Platform API:   http://192.168.219.102:8000
Collection API: http://192.168.219.102:8200
Web:            http://192.168.219.102:3000
```

If this Windows PC is used as a backup analysis/collection host:

```text
Backup Collection/Analysis: http://192.168.219.100:8200
Backup Analysis legacy:     http://192.168.219.100:8100
```

Prefer `8200` for the unified Collection/Analysis path. Treat `8100` as legacy
or direct debugging unless the code path explicitly requires it.

## Starting The Primary Mac Mini

```bash
cd ai_pms_bootstrap
bash scripts/run_lan_execution_stack.sh
```

Then verify:

```bash
bash scripts/doctor_lan_connectivity.sh
```

## Starting This Windows PC As A Backup Node

From this repository path on Windows:

```powershell
cd "<repo-root>"
```

Start the unified analysis/collection server on LAN:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows_run_analysis_server.ps1 `
  -ProjectRoot "$PWD" `
  -BindHost 0.0.0.0 `
  -AllowPublicBind
```

Health URL:

```text
http://192.168.219.100:8200/health
```

Use a unique worker ID for each machine:

```powershell
$env:WORKER_ID="windows-backup-worker-001"
```

If the Windows PC should process the same queue as the primary node, configure
these values in its local `analysis_server/.env` before startup:

```text
DATABASE_URL=<shared Collection/PostgreSQL database URL>
PLATFORM_API_URL=<primary Platform API URL>
AUDIO_STORAGE_DIR=<shared audio path visible to this PC>
WORKER_ID=windows-backup-worker-001
WORKER_LOOP_ENABLED=true
```

Do not expose the shared database directly to the public internet. Use LAN,
VPN, or a private tunnel.

Use real secret values from the local `.env` files only on the machine. Do not
copy secrets into docs, chat, APK metadata, or public handoff bundles.

## Client Fallback Options

There are three levels of fallback. Choose deliberately.

### Option A: Manual Fallback

Build Android against the active Collection host.

Mac mini active:

```bash
LAN_IP=192.168.219.102 bash scripts/build_android_lan_debug.sh
```

Windows backup active:

```bash
AIPMS_PLATFORM_BASE_URL=http://192.168.219.102:8000 \
AIPMS_COLLECTION_BASE_URL=http://192.168.219.100:8200 \
bash scripts/build_android_lan_debug.sh
```

This is the simplest and safest for a demo.

### Option B: App-Level Fallback

Future implementation:

```text
primary collection URL   = http://192.168.219.102:8200
fallback collection URL  = http://192.168.219.100:8200
```

The app should try primary first, then fallback only for network failures before
an upload session is created. Do not retry the same audio upload to two servers
after a session has already been created unless idempotency is implemented.

### Option C: Reverse Proxy Or Stable DNS

Future implementation:

```text
http://aipms-collection.local -> Mac mini 8200
                             -> Windows PC 8200 if primary is down
```

This keeps app builds stable but requires proxy health checks and careful upload
session stickiness.

## Acceptance Checks

From another PC on the same Wi-Fi:

```powershell
Test-NetConnection 192.168.219.102 -Port 8000
Test-NetConnection 192.168.219.102 -Port 8200
Test-NetConnection 192.168.219.100 -Port 8200
```

Expected:

- Primary Platform `8000` succeeds.
- Active Collection `8200` succeeds.
- Backup Collection `8200` succeeds only when intentionally running.
- App/Web still read final meeting state from Platform.

Run the cross-server doctor from the repository root:

```bash
bash scripts/doctor_cross_server_connectivity.sh
```

Check a secondary host as an optional node:

```bash
AIPMS_SECONDARY_HOST=192.168.219.100 bash scripts/doctor_cross_server_connectivity.sh
```

Require the secondary host to be up:

```bash
AIPMS_SECONDARY_HOST=192.168.219.100 \
AIPMS_EXPECT_SECONDARY=1 \
bash scripts/doctor_cross_server_connectivity.sh
```

The report is written to:

```text
runtime/cross_server/latest_report.json
runtime/cross_server/latest_report.md
```

## Do Not Do This

- Do not run two independent Platform databases and expect one app to reconcile
  meeting approval state automatically.
- Do not hard-code `192.168.219.100` or `192.168.219.102` in source files.
- Do not expose `DATABASE_URL`, callback secrets, upload tokens, or bearer tokens
  in guides or chat.
- Do not make Web/Android call `8100` directly for normal product flow.
- Do not assume ping success means API success; test TCP and `/health`.

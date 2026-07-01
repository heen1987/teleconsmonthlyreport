# LAN Connectivity Runbook

For future coding sessions, see
`docs/28_vibe_coding_connectivity_guide.md` before changing client/server
network behavior.

This runbook keeps the client-facing network simple:

```text
Android app / Web
  -> Mac mini Platform API on 8000
  -> Mac mini Collection API on 8200
      -> Mac mini Analysis Worker pulls jobs
      -> Collection callback writes results back to Platform
```

The app and Web client should not call the Analysis server on `8100` directly.
`8100` is useful for local health checks and manual debugging, but the product
flow should go through Platform and Collection.

## Start The LAN Stack

On the Mac mini:

```bash
cd ai_pms_bootstrap
bash scripts/run_lan_execution_stack.sh
```

The script starts these screen sessions:

- PostgreSQL
- Platform API bound to `0.0.0.0:8000`
- Collection API bound to `0.0.0.0:8200`
- Analysis worker loop
- Web dev server bound to `0.0.0.0:3000`

It writes the current URLs to:

```text
runtime/lan_execution/latest_urls.env
```

## Diagnose Connectivity

On the Mac mini:

```bash
cd ai_pms_bootstrap
bash scripts/doctor_lan_connectivity.sh
```

The report is written to:

```text
runtime/lan_connectivity/latest_report.md
runtime/lan_connectivity/latest_report.json
```

Required checks:

- Platform local health: `http://127.0.0.1:8000/health`
- Collection local health: `http://127.0.0.1:8200/health`
- Platform LAN health: `http://<LAN_IP>:8000/health`
- Collection LAN health: `http://<LAN_IP>:8200/health`
- Platform CORS preflight from Web origin
- Platform listener is public on `8000`
- Collection listener is public on `8200`

Optional checks:

- Web LAN home: `http://<LAN_IP>:3000/`
- Analysis local health: `http://127.0.0.1:8100/health`
- Analysis LAN health: `http://<LAN_IP>:8100/health`

## Build Android For LAN

After the doctor passes for Platform and Collection:

```bash
LAN_IP=<Mac-mini-LAN-IP> bash scripts/build_android_lan_debug.sh
```

The APK will use:

```text
Platform API:   http://<Mac-mini-LAN-IP>:8000
Collection API: http://<Mac-mini-LAN-IP>:8200
```

## Manual Startup Fallback

If the stack runner is not appropriate for a debugging session, start these in
separate Mac mini terminals:

```bash
cd ai_pms_bootstrap
bash scripts/run_postgres.sh
```

```bash
cd ai_pms_bootstrap
AIPMS_PLATFORM_BIND_HOST=0.0.0.0 \
AIPMS_PLATFORM_ALLOW_PUBLIC_BIND=1 \
bash scripts/run_platform_backend.sh
```

```bash
cd ai_pms_bootstrap
AIPMS_COLLECTION_BIND_HOST=0.0.0.0 \
AIPMS_COLLECTION_ALLOW_PUBLIC_BIND=1 \
bash scripts/run_collection_api.sh
```

```bash
cd ai_pms_bootstrap
bash scripts/run_analysis_worker_loop.sh
```

```bash
cd ai_pms_bootstrap/web_client
VITE_API_BASE=http://<Mac-mini-LAN-IP>:8000 npm run dev -- --host 0.0.0.0 --port 3000
```

## Expected Failure Meaning

- Ping works but `8000` fails: Platform is not running, not LAN-bound, or blocked by firewall.
- Ping works but `8200` fails: Collection is not running, not LAN-bound, or blocked by firewall.
- `8000` and `8200` work but upload never completes: check the worker loop and Collection callback events.
- `8100` fails from another device: usually acceptable unless direct Analysis debugging is required.

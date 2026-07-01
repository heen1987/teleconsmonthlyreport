# AI-PMS Web Client

React-based first-pass console for W-001 to W-006.

Implemented views:

- dashboard summary
- project selection
- meeting review package
- approval action
- action/decision/risk/resource review sections

Run:

```bash
npm install
npm run dev
```

Repository-level local execution stack:

```bash
cd ..
bash scripts/run_local_execution_stack.sh
```

Environment:

```bash
VITE_API_BASE=http://127.0.0.1:8000
AIPMS_WEB_BIND_HOST=127.0.0.1
AIPMS_WEB_ALLOW_PUBLIC_BIND=0
```

The repository run scripts keep the Web dev server on `127.0.0.1:3000` by
default. Public or LAN binding requires both `AIPMS_WEB_BIND_HOST=0.0.0.0` and
`AIPMS_WEB_ALLOW_PUBLIC_BIND=1`; routine external access should use the
Cloudflare tunnel script from the repository root.

Public routes:

- `/`: authenticated Web console
- `/run/`: Web, API, APK execution hub
- `/downloads/`: Android phone/tablet APK download
- `/downloads/install.html`: APK install and verification guide
- `/handoff/`: owner handoff draft

The React public routes prefer `/run/execution.json` for current public URLs
and APK metadata. Hardcoded public tunnel constants are fallback values only.

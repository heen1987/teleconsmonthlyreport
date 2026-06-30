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
```

Public routes:

- `/`: authenticated Web console
- `/run/`: Web, API, APK execution hub
- `/downloads/`: Android phone/tablet APK download
- `/downloads/install.html`: APK install and verification guide
- `/handoff/`: owner handoff draft

The React public routes prefer `/run/execution.json` for current public URLs
and APK metadata. Hardcoded public tunnel constants are fallback values only.

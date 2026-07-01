# Collection/Analysis Mac mini Runner Runbook

This runbook deploys the Collection API and integrated Analysis worker to the
Mac mini from GitHub Actions.

Platform API is intentionally not restarted by this workflow. Set the public
Platform API URL through repository variables and let Collection call back to
that URL.

## Repository

```text
https://github.com/juyeoon/llm-meeting-assistant
```

## Actual Project Paths

The sample `platform_api` name does not exist in this repository. Use:

| Role | Directory | Port |
|---|---|---:|
| Platform API | external GitHub Actions deployment target | external |
| Collection + Analysis | `collection_api` | `8200` |
| Legacy Analysis Server | `analysis_server` | deprecated |
| Web Client | GitHub Pages | external |

## Runner Registration

In GitHub:

```text
Settings -> Actions -> Runners -> New self-hosted runner -> macOS
```

Run the GitHub-provided commands on the Mac mini. They include a one-time
registration token.

After `./config.sh ...` succeeds, install the runner as a service:

```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

Check:

```bash
sudo ./svc.sh status
```

## Required Repository Variables

The workflow has safe defaults, but these repository variables are recommended:

| Variable | Recommended value |
|---|---|
| `AIPMS_DEPLOY_ROOT` | `/Users/ppp/Documents/새싹_프로젝트1/ai_pms_bootstrap` |
| `AIPMS_PLATFORM_API_URL` | Platform server public HTTPS URL, not a Mac mini/PC LAN IP |

The deploy script preserves `.env`, `.venv`, `storage`, `runtime`, and `logs`
under the deploy root.

## Workflow

`.github/workflows/deploy-mac-mini.yml` runs on pushes to `user/heeseop` and
`main`, using `AIPMS_DEPLOY_PROFILE=collection-analysis`.

Deployment steps:

1. Checkout Git code.
2. Run `scripts/deploy_mac_mini_from_runner.sh --check`.
3. Sync Collection, scripts, contracts, docs, and model assets into
   `AIPMS_DEPLOY_ROOT`.
4. Update `collection_api/.env` `PLATFORM_API_URL` when
   `AIPMS_PLATFORM_API_URL` is provided.
5. Install Collection Python dependencies.
6. Apply Collection schema migrations.
7. Restart `aipms-collection` in a `screen` session.
8. Verify `http://127.0.0.1:8200/health`.

The Analysis worker is an internal asyncio startup task in `collection_api`;
do not run the deprecated external worker loop for the normal Mac mini path.

## Manual Dry Run

From a normal terminal:

```bash
bash scripts/deploy_mac_mini_from_runner.sh --check
bash scripts/deploy_mac_mini_from_runner.sh --sync-only
```

Full deploy:

```bash
AIPMS_DEPLOY_PROFILE=collection-analysis \
AIPMS_PLATFORM_API_URL=<platform-api-public-https-url> \
bash scripts/deploy_mac_mini_from_runner.sh --deploy
```

`AIPMS_PLATFORM_API_URL` is required. The deploy script rejects localhost and
private LAN targets such as `127.0.0.1`, `10.x`, and `192.168.x.x` for the
`collection-analysis` profile because Collection must callback to the Platform
server, not to the Mac mini itself.

## Collection Public Tunnel

After local Collection health is ready, expose only Collection through a quick
tunnel:

```bash
bash scripts/run_collection_analysis_public_tunnel.sh
```

The script verifies:

- `http://127.0.0.1:8200/health`
- `<collection-public-url>/health`

Use the printed Collection URL for Android `aipmsCollectionBaseUrl` or
`AIPMS_PUBLIC_COLLECTION_URL`.

Android public build example:

```bash
AIPMS_PLATFORM_API_URL=<platform-server-public-https-url> \
AIPMS_PUBLIC_COLLECTION_URL=<collection-public-url> \
bash scripts/build_android_public_debug.sh
```

## Notes

- Do not commit `.env` files.
- Do not use `pkill -f uvicorn` in the workflow; it can stop unrelated Python
  processes. The deploy script restarts named `screen` sessions.
- GitHub Pages can still host the static Web separately.
- Publish only the Collection URL required by Android. Do not expose the legacy
  Analysis server as a user-facing endpoint.

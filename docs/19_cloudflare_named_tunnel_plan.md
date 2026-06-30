# Cloudflare Named Tunnel Plan

Last updated: 2026-06-29

## Purpose

The current public URLs use Cloudflare quick tunnels. They are enough for team
review, but the URL changes whenever the tunnel is recreated. A Cloudflare
named tunnel should be used for stable demonstration or external review URLs.

## Target Host Mapping

| Hostname | Local service | Local port |
|---|---|---|
| `pms.example.com` | React Web | `3000` |
| `api.pms.example.com` | Platform API | `8000` |
| `collection.pms.example.com` | Collection API | `8200` |
| `analysis.pms.example.com` | Analysis Server | `8100` |

Actual hostnames should be provided by the Cloudflare account owner.

## Preparation

```bash
cloudflared tunnel login
cloudflared tunnel create ai-pms
cloudflared tunnel route dns ai-pms pms.example.com
cloudflared tunnel route dns ai-pms api.pms.example.com
cloudflared tunnel route dns ai-pms collection.pms.example.com
cloudflared tunnel route dns ai-pms analysis.pms.example.com
```

Then export the resolved values:

```bash
export AIPMS_CF_TUNNEL_ID="<cloudflare-tunnel-id>"
export AIPMS_CF_WEB_HOSTNAME="pms.example.com"
export AIPMS_CF_PLATFORM_HOSTNAME="api.pms.example.com"
export AIPMS_CF_COLLECTION_HOSTNAME="collection.pms.example.com"
export AIPMS_CF_ANALYSIS_HOSTNAME="analysis.pms.example.com"
```

Generate the runtime config:

```bash
bash scripts/prepare_cloudflare_named_tunnel.sh
```

The script always writes:

- `runtime/cloudflare_named_tunnel/config.example.yml`

When the `AIPMS_CF_*` values are present, it also writes:

- `runtime/cloudflare_named_tunnel/config.yml`

## Run

Start the base services first:

```bash
bash scripts/run_postgres.sh
bash scripts/run_collection_api.sh
bash scripts/run_analysis_server.sh
bash scripts/run_platform_backend.sh
```

Start Web with the fixed Platform API hostname:

```bash
cd web_client
VITE_API_BASE=https://api.pms.example.com npm run dev -- --host 0.0.0.0 --port 3000 --cors
```

Start the named tunnel:

```bash
cd ..
bash scripts/run_cloudflare_named_tunnel.sh
```

## Android Public Build

Once the named tunnel is live, build the Android APK against the fixed
Platform and Collection hostnames:

```bash
AIPMS_PUBLIC_PLATFORM_URL=https://api.pms.example.com \
AIPMS_PUBLIC_COLLECTION_URL=https://collection.pms.example.com \
bash scripts/build_android_public_debug.sh
```

Then publish it to the Web download route:

```bash
bash scripts/publish_android_apk_download.sh
```

## Remaining Operations

- Cloudflare account login and DNS ownership are required.
- The public debug APK should move to release signing before long-term
  distribution.
- Named tunnel hostnames should replace quick tunnel URLs in
  `docs/18_part_handoff_drafts.md` after the DNS routes are live.

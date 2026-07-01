# Cloudflare Named Tunnel Plan

Last updated: 2026-07-01

## Purpose

Quick tunnels are useful for temporary team review, but their URLs can change
when the tunnel process is recreated. A named Cloudflare tunnel can be used
when the API endpoints need stable public URLs.

The Web client is now expected to use the GitHub Pages default project URL.
Do not add a Web custom-domain `CNAME` unless a new domain decision is made.

## Target Host Mapping

Use repository or shell variables instead of hard-coded hostnames:

| Variable | Local service | Local port |
|---|---|---|
| `AIPMS_CF_PLATFORM_HOSTNAME` | Platform API | `8000` |
| `AIPMS_CF_COLLECTION_HOSTNAME` | Collection API | `8200` |

Do not expose Analysis `8100` as a normal product endpoint. Keep it local, or
publish it only for controlled debugging with a separate temporary URL.

## Preparation

```bash
cloudflared tunnel login
cloudflared tunnel create <tunnel-name>
cloudflared tunnel route dns <tunnel-name> <platform-api-hostname>
cloudflared tunnel route dns <tunnel-name> <collection-api-hostname>
```

Then export the resolved values:

```bash
export AIPMS_CF_TUNNEL_ID="<cloudflare-tunnel-id>"
export AIPMS_CF_PLATFORM_HOSTNAME="<platform-api-hostname>"
export AIPMS_CF_COLLECTION_HOSTNAME="<collection-api-hostname>"
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

Start the named tunnel:

```bash
bash scripts/run_cloudflare_named_tunnel.sh
```

## Web Deployment

Deploy Web through GitHub Pages:

```bash
cd web_client
VITE_API_BASE=<platform-api-public-url> \
VITE_BASE_PATH=/llm-meeting-assistant/ \
npm run build
```

For repository deployment, set `AIPMS_PLATFORM_URL` in GitHub repository
variables and use `.github/workflows/deploy-web-pages.yml`.

## Android Public Build

Once public Platform and Collection URLs are available, build the Android APK
against those endpoints:

```bash
AIPMS_PUBLIC_PLATFORM_URL=<platform-api-public-url> \
AIPMS_PUBLIC_COLLECTION_URL=<collection-api-public-url> \
bash scripts/build_android_public_debug.sh
```

Then publish it to the Web download route:

```bash
bash scripts/publish_android_apk_download.sh
```

## Remaining Operations

- Cloudflare account login and DNS ownership are required for named tunnels.
- The public debug APK should move to release signing before long-term
  distribution.
- Platform CORS must include the GitHub Pages origin and any approved API
  testing origins.

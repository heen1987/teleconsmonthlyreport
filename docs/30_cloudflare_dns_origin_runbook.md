# Cloudflare DNS Origin Runbook

This runbook covers the direct Cloudflare DNS `A` record path:

```text
User browser
  -> Cloudflare proxied DNS
  -> server public IP
  -> router port-forward 80/443
  -> Mac mini reverse proxy
  -> AI-PMS local services
```

Use this path only when the router can forward ports `80` and `443` to the Mac
mini. If port-forwarding is not available, use the Cloudflare named tunnel plan
in `docs/19_cloudflare_named_tunnel_plan.md`.

## Current Origin Values

Current observed values on 2026-07-01:

```text
Public IP: 115.138.61.210
Mac mini LAN IP: 192.168.219.103
```

Recheck before changing DNS:

```bash
curl ifconfig.me
ipconfig getifaddr en0
ipconfig getifaddr en1
```

## Cloudflare DNS Records

For a root domain such as `example.com`:

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `@` | `115.138.61.210` | on |
| A | `www` | `115.138.61.210` | on |
| A | `api` | `115.138.61.210` | on |
| A | `collection` | `115.138.61.210` | on |

Do not expose `analysis` as a normal product endpoint. Web and Android should
use Platform and Collection only.

## Router Port Forwarding

Forward these TCP ports to the Mac mini LAN IP:

| External | Internal Host | Internal Port |
|---:|---|---:|
| 80 | `192.168.219.103` | 80 |
| 443 | `192.168.219.103` | 443 |

The app services currently listen on local development ports:

| Service | Local target |
|---|---|
| Web | `127.0.0.1:3000` |
| Platform API | `127.0.0.1:8000` |
| Collection API | `127.0.0.1:8200` |
| Analysis | `127.0.0.1:8100` |

Cloudflare cannot reach `3000`, `8000`, or `8200` through proxied `A` records
unless a reverse proxy is listening on `80` and `443`.

## Reverse Proxy Shape

Caddy or Nginx should route hostnames like this:

```text
pms.example.com          -> http://127.0.0.1:3000
www.example.com          -> http://127.0.0.1:3000
api.example.com          -> http://127.0.0.1:8000
collection.example.com   -> http://127.0.0.1:8200
```

Recommended Cloudflare SSL mode:

```text
Full (strict)
```

If local certificate setup is not ready yet, use a named tunnel instead of
weakening the origin.

## Doctor

Run the origin doctor:

```bash
bash scripts/doctor_cloudflare_dns_origin.sh
```

If the reverse proxy should already be live:

```bash
AIPMS_EXPECT_ORIGIN_PROXY=1 bash scripts/doctor_cloudflare_dns_origin.sh
```

If DNS hostnames should already be live:

```bash
AIPMS_DOMAIN_ROOT=example.com \
AIPMS_DOMAIN_WEB=pms.example.com \
AIPMS_DOMAIN_PLATFORM=api.example.com \
AIPMS_DOMAIN_COLLECTION=collection.example.com \
AIPMS_EXPECT_ORIGIN_PROXY=1 \
AIPMS_EXPECT_DOMAIN_LIVE=1 \
bash scripts/doctor_cloudflare_dns_origin.sh
```

Reports:

```text
runtime/cloudflare_dns_origin/latest_report.json
runtime/cloudflare_dns_origin/latest_report.md
```

## Acceptance Criteria

- Public IP is present.
- Mac mini LAN IP is present.
- Local Web, Platform, and Collection health checks return HTTP 200.
- Router forwards external `80` and `443` to the Mac mini.
- Reverse proxy listens on local `80` and `443`.
- Domain Web route returns HTTP 200.
- Domain Platform route returns HTTP 200 at `/health`.
- Domain Collection route returns HTTP 200 at `/health`.

## Security Notes

- Keep Platform and Collection auth enabled.
- Do not expose database ports to the internet.
- Do not expose Analysis `8100` as a user-facing endpoint.
- Do not publish callback secrets, bearer tokens, or upload tokens.
- Prefer Cloudflare named tunnel when the ISP IP changes often or the router
  cannot forward ports reliably.

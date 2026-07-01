# GitHub Pages Web Deployment

## Target Architecture

```text
https://juyeoon.github.io/llm-meeting-assistant/
  -> GitHub Pages static React Web

Platform server
  -> externally reachable HTTPS URL
  -> repository variable AIPMS_PLATFORM_URL

Mac mini Collection / Analysis
  -> remain server-side services behind Platform API and the Android app flow
```

GitHub Actions builds and publishes the Web. It does not run a permanent API
server. Web calls the Platform server URL from repository variables.
Collection/Analysis, Postgres, workers, and audio storage run on the Mac mini.

## Repository Settings

In GitHub:

```text
Settings -> Pages -> Build and deployment -> Source: GitHub Actions
Settings -> Secrets and variables -> Actions -> Variables
```

Required variable:

```text
AIPMS_PLATFORM_URL=<Platform server public HTTPS URL>
```

Optional variable:

```text
AIPMS_PAGES_BASE_PATH=/llm-meeting-assistant/
```

Do not configure a custom domain for this mode. `web_client/public/CNAME` is not
used.

## Verification

Local build equivalent:

```bash
cd web_client
VITE_API_BASE=<Platform server public HTTPS URL> \
VITE_BASE_PATH=/llm-meeting-assistant/ \
npm run build
```

CORS check:

```bash
bash scripts/smoke_github_pages_cors.sh <Platform server public HTTPS URL>
```

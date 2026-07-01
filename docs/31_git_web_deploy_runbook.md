# Git Web Deploy Runbook

This runbook uses GitHub Pages for the React Web client without a custom domain.

## Target Shape

```text
Git push
  -> GitHub Actions
  -> build web_client
  -> GitHub Pages
  -> https://juyeoon.github.io/llm-meeting-assistant/

Web API calls
  -> Platform server public HTTPS URL
  -> Platform server

Audio upload calls
  -> Android app / Collection API public URL
  -> Mac mini Collection API
```

GitHub Pages hosts the Web only. GitHub Actions builds/deploys the static Web;
it does not run permanent backend servers. Platform is an external server URL;
Collection/Analysis, database, workers, and audio storage run on the Mac mini.

## Files

- `.github/workflows/deploy-web-pages.yml`
- `web_client/vite.config.ts`
- `scripts/smoke_github_pages_cors.sh`

`web_client/public/CNAME` must not exist unless a custom domain is restored.

## GitHub Repository Settings

In the GitHub repository:

1. Open `Settings -> Pages`.
2. Set `Build and deployment` to `GitHub Actions`.
3. Set repository variable `AIPMS_PLATFORM_URL` to the Platform server public
   HTTPS URL.

Example:

```text
AIPMS_PLATFORM_URL=https://<platform-public-url>
```

Optional variable:

```text
AIPMS_PAGES_BASE_PATH=/llm-meeting-assistant/
```

If `AIPMS_PLATFORM_URL` is not set, the workflow fails intentionally so the Web
is not deployed with a broken API target.

## URL

```text
https://juyeoon.github.io/llm-meeting-assistant/
```

## Local Verification

```bash
cd web_client
VITE_API_BASE=<platform-server-public-HTTPS-URL> \
VITE_BASE_PATH=/llm-meeting-assistant/ \
npm run build
```

```bash
bash scripts/smoke_github_pages_cors.sh <platform-server-public-HTTPS-URL>
```

## Deploy

```bash
git add ai_pms_bootstrap
git commit -m "Deploy web client through GitHub Pages"
git push origin main
```

GitHub Actions publishes the Web artifact after the push.

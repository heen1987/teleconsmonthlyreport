#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ANDROID_MAIN="android_client/src/main/java/com/aipms/MainActivity.kt"
PUBLIC_HTML=(
  "web_client/public/downloads/index.html"
  "web_client/public/downloads/install.html"
  "web_client/public/handoff/index.html"
  "web_client/public/run/index.html"
)

echo "Checking Android internal-control exposure"
for pattern in \
  'attachChild\(platformUrlInput\)' \
  'attachChild\(collectionUrlInput\)' \
  'attachChild\(requestedByInput\)' \
  'addView\(platformUrlInput\)' \
  'addView\(collectionUrlInput\)' \
  'addView\(requestedByInput\)'
do
  if rg -n "$pattern" "$ANDROID_MAIN"; then
    echo "Android app must not expose internal connection/request fields: $pattern" >&2
    exit 1
  fi
done

python3 - <<'PY'
from __future__ import annotations

import html.parser
import re
from pathlib import Path

root = Path.cwd()
android_main = root / "android_client/src/main/java/com/aipms/MainActivity.kt"
public_html = [
    root / "web_client/public/downloads/index.html",
    root / "web_client/public/downloads/install.html",
    root / "web_client/public/handoff/index.html",
    root / "web_client/public/run/index.html",
]

forbidden_visible_terms = [
    "서버",
    "프롬프트",
    "수정 프롬프트",
    "localhost",
    "127.0.0.1",
    "trycloudflare",
    "VITE_",
    "npm",
    "bash",
    "python",
    "curl",
]

android_visible_call = re.compile(
    r'(?:text\s*=\s*|setStatus\(|toast\(|button\(|input\(|passwordInput\(|sectionCard\()\s*"([^"]*)"',
    re.MULTILINE,
)


def fail(message: str) -> None:
    raise SystemExit(message)


android_source = android_main.read_text(encoding="utf-8")
for match in android_visible_call.finditer(android_source):
    text = match.group(1)
    for term in forbidden_visible_terms:
        if term in text:
            fail(f"Android visible text contains forbidden term {term!r}: {text!r}")


class VisibleTextParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.hidden_depth = 0
        self.texts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() in {"script", "style"}:
            self.hidden_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"script", "style"} and self.hidden_depth:
            self.hidden_depth -= 1

    def handle_data(self, data: str) -> None:
        text = " ".join(data.split())
        if text and not self.hidden_depth:
            self.texts.append(text)


for path in public_html:
    parser = VisibleTextParser()
    parser.feed(path.read_text(encoding="utf-8"))
    for text in parser.texts:
        for term in forbidden_visible_terms:
            if term in text:
                fail(f"{path.relative_to(root)} visible text contains forbidden term {term!r}: {text!r}")

print("user-facing copy guard passed")
PY

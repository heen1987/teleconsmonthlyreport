#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="${REVIEW_RESPONSE_INBOX_DIR:-$ROOT_DIR/runtime/review_responses/inbox}"
OUTPUT_DIR="${REVIEW_RESPONSE_OUTPUT_DIR:-$ROOT_DIR/runtime/review_responses}"
SUMMARY_JSON="$OUTPUT_DIR/latest_summary.json"
SUMMARY_MD="$OUTPUT_DIR/latest_summary.md"
INSTRUCTIONS="$INBOX_DIR/_README.md"

mkdir -p "$INBOX_DIR" "$OUTPUT_DIR"

if [ ! -f "$INSTRUCTIONS" ]; then
  cat > "$INSTRUCTIONS" <<'EOF'
# Review Response Inbox

Place filled copies of `web_client/public/handoff/review-response-template.md`
in this directory, then run:

```bash
bash scripts/collect_public_review_responses.sh
```

Suggested filenames:

- `review-response-kim-heeseop.md`
- `review-response-kim-ganghyeon.md`
- `review-response-park-juyeon.md`
EOF
fi

export INBOX_DIR OUTPUT_DIR SUMMARY_JSON SUMMARY_MD

python3 - <<'PY'
from __future__ import annotations

import datetime as dt
import json
import os
import re
from pathlib import Path

inbox_dir = Path(os.environ["INBOX_DIR"])
summary_json = Path(os.environ["SUMMARY_JSON"])
summary_md = Path(os.environ["SUMMARY_MD"])
allowed_results = {"승인 가능", "수정 필요", "질문", "미검증"}


def extract_line(text: str, label: str) -> str:
    pattern = re.compile(rf"^- {re.escape(label)}:\s*(.*)$", re.MULTILINE)
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def normalize_result(raw: str) -> str:
    value = raw.strip()
    if value in allowed_results:
        return value
    if not value or "/" in value:
        return "미검증"
    return value


def section(text: str, heading: str) -> str:
    marker = f"## {heading}"
    start = text.find(marker)
    if start == -1:
        return ""
    rest = text[start + len(marker):]
    next_heading = rest.find("\n## ")
    return rest if next_heading == -1 else rest[:next_heading]


def count_change_rows(text: str) -> dict[str, int]:
    changes = {"P1": 0, "P2": 0, "P3": 0}
    change_section = section(text, "수정 요청")
    for line in change_section.splitlines():
        for priority in changes:
            if re.search(rf"\|\s*{priority}\b", line):
                changes[priority] += 1
    return changes


def count_question_rows(text: str) -> int:
    question_section = section(text, "질문")
    count = 0
    for line in question_section.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        if "---" in stripped or stripped.startswith("| 질문"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if any(cells):
            count += 1
    return count


def count_unverified_items(text: str) -> int:
    unverified_section = section(text, "미검증 항목")
    count = 0
    for line in unverified_section.splitlines():
        stripped = line.strip()
        if stripped.startswith("-") and stripped not in {"-", "- "}:
            count += 1
    return count


responses = []
for path in sorted(inbox_dir.glob("*.md")):
    if path.name.startswith("_"):
        continue
    text = path.read_text(encoding="utf-8")
    result = normalize_result(extract_line(text, "결과"))
    changes = count_change_rows(text)
    responses.append(
        {
            "file": str(path),
            "reviewer": extract_line(text, "검토자"),
            "scope": extract_line(text, "담당 범위"),
            "result": result,
            "summary": extract_line(text, "한 줄 요약"),
            "change_requests": changes,
            "questions": count_question_rows(text),
            "unverified_items": count_unverified_items(text),
        }
    )

result_counts = {key: 0 for key in ["승인 가능", "수정 필요", "질문", "미검증"]}
for response in responses:
    result_counts[response["result"]] = result_counts.get(response["result"], 0) + 1

summary = {
    "kind": "public_review_response_summary",
    "collected_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "inbox_dir": str(inbox_dir),
    "response_count": len(responses),
    "result_counts": result_counts,
    "responses": responses,
    "next_actions": [
        "Resolve P1/P2 change requests before demo or external handoff.",
        "Convert open questions into decisions or backlog items.",
        "Keep unverified items visible until a device/API smoke confirms them.",
    ],
}

summary_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lines = [
    "# AI-PMS Review Response Summary",
    "",
    f"- Collected at: {summary['collected_at']}",
    f"- Inbox: `{inbox_dir}`",
    f"- Response count: {len(responses)}",
    "",
    "## Result Counts",
    "",
    "| Result | Count |",
    "|---|---:|",
]
for key, value in result_counts.items():
    lines.append(f"| {key} | {value} |")

lines.extend(["", "## Responses", "", "| Reviewer | Scope | Result | Summary | P1 | P2 | P3 | Questions | Unverified |", "|---|---|---|---|---:|---:|---:|---:|---:|"])
for response in responses:
    changes = response["change_requests"]
    lines.append(
        "| {reviewer} | {scope} | {result} | {summary} | {p1} | {p2} | {p3} | {questions} | {unverified} |".format(
            reviewer=response["reviewer"] or "-",
            scope=response["scope"] or "-",
            result=response["result"],
            summary=(response["summary"] or "-").replace("|", "/"),
            p1=changes["P1"],
            p2=changes["P2"],
            p3=changes["P3"],
            questions=response["questions"],
            unverified=response["unverified_items"],
        )
    )

if not responses:
    lines.append("| - | - | 미검증 | No response files in inbox. | 0 | 0 | 0 | 0 | 0 |")

summary_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

cat <<EOF
Collected public review responses.

Inbox:
  $INBOX_DIR

Summary:
  $SUMMARY_JSON
  $SUMMARY_MD
EOF

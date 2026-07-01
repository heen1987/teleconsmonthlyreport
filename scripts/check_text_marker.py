#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 5 or sys.argv[1] not in {"present", "absent"}:
        print(
            "usage: check_text_marker.py present|absent <file> <literal> <label>",
            file=sys.stderr,
        )
        return 2

    mode, file_name, literal, label = sys.argv[1:]
    path = Path(file_name)
    if not path.exists():
        print(f"missing {label} file: {path}", file=sys.stderr)
        return 1

    stat = path.stat()
    if stat.st_size > 0 and getattr(stat, "st_blocks", 1) == 0:
        print(
            f"cannot check {label}; Google Drive placeholder is offline: {path}",
            file=sys.stderr,
        )
        return 74

    text = path.read_text(encoding="utf-8")
    found = literal in text

    if mode == "present" and not found:
        print(f"missing {label} in {path}: {literal}", file=sys.stderr)
        return 1
    if mode == "absent" and found:
        print(f"unexpected {label} in {path}: {literal}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

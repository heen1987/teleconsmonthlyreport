#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="${AIPMS_OPERATIONS_RECOVERY_LABEL:-com.aipms.operations-recovery}"
INTERVAL_SECONDS="${AIPMS_OPERATIONS_RECOVERY_INTERVAL_SECONDS:-3600}"
LIMIT="${AIPMS_OPERATIONS_RECOVERY_LIMIT:-10}"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
LOG_DIR="${ROOT_DIR}/logs"
MODE="${1:---install}"

usage() {
  cat <<EOF
Usage: bash scripts/install_launchd_operations_recovery.sh [--install|--load|--unload|--check|--print]

Modes:
  --install  Write the LaunchAgent plist only. This is the default.
  --load     Write and load the LaunchAgent for the current macOS user.
  --unload   Unload the LaunchAgent if it is currently loaded.
  --check    Render and lint the plist without installing it.
  --print    Print the plist to stdout.

Environment overrides:
  AIPMS_OPERATIONS_RECOVERY_LABEL
  AIPMS_OPERATIONS_RECOVERY_INTERVAL_SECONDS
  AIPMS_OPERATIONS_RECOVERY_LIMIT
EOF
}

render_plist() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${ROOT_DIR}/scripts/run_operations_recovery_once.sh</string>
    <string>${LIMIT}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ROOT_DIR}</string>
  <key>StartInterval</key>
  <integer>${INTERVAL_SECONDS}</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/operations_recovery.launchd.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/operations_recovery.launchd.err</string>
</dict>
</plist>
EOF
}

write_plist() {
  mkdir -p "$PLIST_DIR" "$LOG_DIR"
  render_plist > "$PLIST_PATH"
  plutil -lint "$PLIST_PATH" >/dev/null
  echo "Installed plist: $PLIST_PATH"
}

unload_plist() {
  if [[ -f "$PLIST_PATH" ]]; then
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
    launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
    echo "Unloaded LaunchAgent: $LABEL"
  else
    echo "No plist found: $PLIST_PATH"
  fi
}

case "$MODE" in
  --install)
    write_plist
    echo "Load with: bash scripts/install_launchd_operations_recovery.sh --load"
    ;;
  --load)
    write_plist
    unload_plist
    if launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1; then
      launchctl kickstart -k "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
    else
      launchctl load "$PLIST_PATH"
    fi
    echo "Loaded LaunchAgent: $LABEL every ${INTERVAL_SECONDS}s"
    ;;
  --unload)
    unload_plist
    ;;
  --check)
    tmp_plist="$(mktemp)"
    render_plist > "$tmp_plist"
    plutil -lint "$tmp_plist"
    rm -f "$tmp_plist"
    ;;
  --print)
    render_plist
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

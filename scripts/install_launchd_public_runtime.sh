#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="${AIPMS_PUBLIC_RUNTIME_LABEL:-com.aipms.public-runtime}"
INTERVAL_SECONDS="${AIPMS_PUBLIC_RUNTIME_INTERVAL_SECONDS:-300}"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
LOG_DIR="${ROOT_DIR}/logs"
WRAPPER_DIR="${HOME}/.aipms"
STATE_DIR="${AIPMS_PUBLIC_RUNTIME_STATE_DIR:-${HOME}/.aipms/public-runtime-state}"
LAUNCHD_LOG_DIR="${STATE_DIR}/logs"
WRAPPER_PATH="${WRAPPER_DIR}/ensure_public_runtime.sh"
INNER_PATH="${WRAPPER_DIR}/ensure_public_runtime_inner.sh"
MODE="${1:---install}"

usage() {
  cat <<EOF
Usage: bash scripts/install_launchd_public_runtime.sh [--install|--load|--unload|--check|--print|--status]

Modes:
  --install  Write the LaunchAgent plist only. This is the default.
  --load     Write and load the LaunchAgent for the current macOS user.
  --unload   Unload the LaunchAgent if it is currently loaded.
  --check    Render and lint the plist without installing it.
  --print    Print the plist to stdout.
  --status   Print launchctl status for the LaunchAgent.

Environment overrides:
  AIPMS_PUBLIC_RUNTIME_LABEL
  AIPMS_PUBLIC_RUNTIME_INTERVAL_SECONDS
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
    <string>${WRAPPER_PATH}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${HOME}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StartInterval</key>
  <integer>${INTERVAL_SECONDS}</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LAUNCHD_LOG_DIR}/public_runtime.launchd.log</string>
  <key>StandardErrorPath</key>
  <string>${LAUNCHD_LOG_DIR}/public_runtime.launchd.err</string>
</dict>
</plist>
EOF
}

write_plist() {
  mkdir -p "$PLIST_DIR" "$LOG_DIR" "$LAUNCHD_LOG_DIR" "$WRAPPER_DIR"
  : > "$LAUNCHD_LOG_DIR/public_runtime.launchd.log"
  : > "$LAUNCHD_LOG_DIR/public_runtime.launchd.err"
  cp "$ROOT_DIR/scripts/public_runtime_watchdog.sh" "$INNER_PATH"
  chmod +x "$INNER_PATH"
  cat > "$WRAPPER_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export AIPMS_RUNTIME_ROOT="$ROOT_DIR"
export AIPMS_PUBLIC_RUNTIME_STATE_DIR="$STATE_DIR"
exec /bin/bash "$INNER_PATH"
EOF
  chmod +x "$WRAPPER_PATH"
  render_plist > "$PLIST_PATH"
  plutil -lint "$PLIST_PATH" >/dev/null
  echo "Installed plist: $PLIST_PATH"
  echo "Installed wrapper: $WRAPPER_PATH"
  echo "Runtime state: $STATE_DIR"
}

unload_plist() {
  if [ -f "$PLIST_PATH" ]; then
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
    echo "Load with: bash scripts/install_launchd_public_runtime.sh --load"
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
  --status)
    launchctl print "gui/$(id -u)/${LABEL}" || true
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

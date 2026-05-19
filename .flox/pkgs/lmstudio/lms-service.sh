#!/usr/bin/env bash
set -euo pipefail
# lms-service — headless LM Studio service launcher (Linux)
#
# Placeholders replaced at build time by substituteInPlace:
#   @lms@          — .lms-unwrapped binary (with LD_LIBRARY_PATH set below)
#   @lm_studio@    — lm-studio AppImage wrapper
#   @xvfb@         — Xvfb binary
#   @lib_path@     — LD_LIBRARY_PATH for .lms-unwrapped

export LD_LIBRARY_PATH="@lib_path@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Log to both stdout (captured by flox services logs) and log file
log_dir="${LMS_LOG_DIR:-$HOME/.lmstudio/logs}"
mkdir -p "$log_dir"
log_file="$log_dir/lm-studio.log"

log() { echo "[lms-service] $*" | tee -a "$log_file"; }

# Ensure lms can find the Electron binary
config_dir="${HOME}/.lmstudio/.internal"
mkdir -p "$config_dir"
echo '{"installLocation":"@lm_studio@"}' > "$config_dir/app-install-location.json"

# Find a free display number for Xvfb
display_num=99
while [ -e "/tmp/.X${display_num}-lock" ] && [ "$display_num" -lt 200 ]; do
  display_num=$((display_num + 1))
done
export DISPLAY=":$display_num"

# Start Xvfb (Electron requires X even in headless mode)
log "Starting Xvfb on DISPLAY=$DISPLAY"
@xvfb@ "$DISPLAY" -screen 0 1024x768x24 -nolisten tcp >> "$log_file" 2>&1 &
xvfb_pid=$!

cleanup() {
  log "Shutting down..."
  @lms@ server stop 2>/dev/null || true
  @lms@ daemon down 2>/dev/null || true
  kill "$xvfb_pid" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

sleep 0.5

# Clean stale daemon state
@lms@ daemon down 2>/dev/null || true

# Start LM Studio app in the background.
# On Linux the AppImage wrapper invokes bwrap which stays alive as a child,
# so we must background it to reach the polling loop below.
log "Starting LM Studio app..."
@lm_studio@ --run-as-service >> "$log_file" 2>&1 &

# Wait for app to initialize, then start the API server
log "Waiting for app to initialize (10s)..."
sleep 10
attempts=0
max_attempts=30
while [ "$attempts" -lt "$max_attempts" ]; do
  attempts=$((attempts + 1))
  # Pass --port and --bind explicitly: lms's stateful "last used"
  # port default and its LMS_SERVER_HOST-only host hook would
  # otherwise diverge from this env's LMS_HOST/LMS_PORT contract.
  # --cors is opt-in via LMS_CORS (set to anything except "0").
  cors_flag=()
  if [ -n "${LMS_CORS:-}" ] && [ "${LMS_CORS}" != "0" ]; then
    cors_flag=("--cors")
  fi
  if @lms@ server start \
        --port "${LMS_PORT:-1234}" \
        --bind "${LMS_HOST:-127.0.0.1}" \
        "${cors_flag[@]}" \
        2>&1 | tee -a "$log_file"; then
    log "API server started on ${LMS_HOST:-127.0.0.1}:${LMS_PORT:-1234}"
    break
  fi
  log "Waiting for API server... (attempt $attempts/$max_attempts)"
  sleep 2
done

if [ "$attempts" -ge "$max_attempts" ]; then
  log "ERROR: API server failed to start after $max_attempts attempts"
fi

# Keep the service alive — sleep in a loop so flox can manage the process.
# On SIGTERM (flox services stop), the trap fires and cleans up.
while true; do sleep 86400; done

#!/usr/bin/env bash
set -euo pipefail
# lms-service — headless LM Studio service launcher (macOS)
#
# Placeholders replaced at build time by substituteInPlace:
#   @lms@          — .lms-unwrapped binary
#   @lm_studio@    — lm-studio wrapper

# Log to both stdout (captured by flox services logs) and log file
log_dir="${LMS_LOG_DIR:-$HOME/.lmstudio/logs}"
mkdir -p "$log_dir"
log_file="$log_dir/lm-studio.log"

log() { echo "[lms-service] $*" | tee -a "$log_file"; }

# Ensure lms can find the Electron binary
config_dir="${HOME}/.lmstudio/.internal"
mkdir -p "$config_dir"
echo '{"installLocation":"@lm_studio@"}' > "$config_dir/app-install-location.json"

# Clean stale daemon state
@lms@ daemon down 2>/dev/null || true

cleanup() {
  log "Shutting down..."
  @lms@ server stop 2>/dev/null || true
  @lms@ daemon down 2>/dev/null || true
}
trap cleanup EXIT TERM INT

log "Starting LM Studio app..."
@lm_studio@ --run-as-service >> "$log_file" 2>&1 &

# Wait for app to initialize, then start the API server
log "Waiting for app to initialize (10s)..."
sleep 10
attempts=0
max_attempts=30
while [ "$attempts" -lt "$max_attempts" ]; do
  attempts=$((attempts + 1))
  if @lms@ server start 2>&1 | tee -a "$log_file"; then
    log "API server started on port ${LMS_PORT:-1234}"
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

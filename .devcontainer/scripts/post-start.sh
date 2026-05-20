#!/usr/bin/env bash
#
# Runs every time the devcontainer starts (including
# Codespace resume). Starts services if the env declares
# any. Idempotent — flox services start is a no-op when
# services are already running.
#
set -euo pipefail

ENV_DIR="${1:?usage: post-start.sh <env-dir>}"
WS_ENV="/workspaces/floxenvs/$ENV_DIR"

# Detect services from the merged config (catches services
# contributed by [include]'d envs).
has_services="$(flox list -d "$WS_ENV" -c 2>/dev/null \
  | grep -c '^\[services\.' || true)"

if [ "$has_services" != "0" ]; then
  # || true: a failed service must not prevent the user
  # getting a shell — Codespaces marks the container
  # broken if postStartCommand exits non-zero.
  flox activate -d "$WS_ENV" \
    -c 'flox services start' || true
fi

echo "post-start.sh done for $ENV_DIR (services=$has_services)"

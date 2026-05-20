#!/usr/bin/env bash
#
# Runs once after the devcontainer is built.
# - Pre-resolves and downloads the env's packages so the
#   first VS Code shell doesn't sit on a cold nix pull.
# - Adds an auto-activate snippet to /root/.bashrc so VS
#   Code terminals inherit the env vars.
#
set -euo pipefail

ENV_DIR="${1:?usage: post-create.sh <env-dir>}"
WS_ENV="/workspaces/floxenvs/$ENV_DIR"

# Codespaces clones repos as root with non-root file
# ownership in some setups. Mark the workspace safe.
git config --global --add safe.directory \
  /workspaces/floxenvs

# Pre-resolve. The `-- true` form runs activation hooks
# and exits — perfect for warm-up.
flox activate -d "$WS_ENV" -- true

# Auto-activate in every new bash shell.
cat >> /root/.bashrc <<EOF

# Added by floxenvs devcontainer post-create.sh
if [ -z "\${FLOX_ENV:-}" ] && [ -d "$WS_ENV/.flox" ]; then
  eval "\$(flox activate -d "$WS_ENV" \\
    --print-script 2>/dev/null || true)"
fi
EOF

echo "post-create.sh done for $ENV_DIR"

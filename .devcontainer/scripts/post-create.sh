#!/usr/bin/env bash
#
# Runs once after the devcontainer is built.
# - Installs flox from the official Debian package (the
#   base image is mcr.microsoft.com/devcontainers/base:
#   ubuntu26.04, so VS Code Remote Server, sshd, node etc.
#   all work out of the box).
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

# Install flox from the official .deb if not already
# present. The /nix store is on a named volume, so on
# container rebuild flox-as-binary is gone but the store
# payload is preserved — dpkg -i is idempotent and fast
# in that case.
if ! command -v flox >/dev/null 2>&1; then
  : "${FLOX_VERSION:?FLOX_VERSION must be set in containerEnv}"
  case "$(uname -m)" in
    x86_64)  ARCH=x86_64  ;;
    aarch64) ARCH=aarch64 ;;
    *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
  esac
  # downloads.flox.dev URLs use the bare version without
  # the "v" prefix that the flake.nix tag carries.
  VER="${FLOX_VERSION#v}"
  DEB_URL="https://downloads.flox.dev/by-env/stable/deb/flox-${VER}.${ARCH}-linux.deb"
  echo "Installing flox ${VER} for ${ARCH} from ${DEB_URL}"
  curl --fail --location --silent --show-error \
    -o /tmp/flox.deb "$DEB_URL"
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    /tmp/flox.deb
  rm -f /tmp/flox.deb
fi

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

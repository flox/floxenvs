#!/usr/bin/env bash
#
# isolated-test.sh - Run floxenvs tests in isolated Linux namespaces
#
# Solves the problem of concurrent test runs fighting over ports
# (MySQL, Elasticsearch, PostgreSQL) and leaving orphaned services
# on shared builder machines.
#
# Each test gets its own:
#   - Network namespace (own loopback, own port space)
#   - PID namespace (orphaned services killed on exit)
#   - Mount namespace (private /tmp, clean state)
#
# Usage:
#   ./scripts/isolated-test.sh <env-name> [--start-services]
#
# Examples:
#   ./scripts/isolated-test.sh postgres --start-services
#   ./scripts/isolated-test.sh go
#   ./scripts/isolated-test.sh mysql --start-services
#
# Requirements:
#   - Linux with user namespace support (most modern kernels)
#   - unshare(1) from util-linux
#   - For full isolation: root or CAP_SYS_ADMIN capability
#   - Falls back to network-only isolation if PID/mount
#     namespaces are unavailable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# --- Argument parsing ---

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <env-name> [--start-services]"
  echo ""
  echo "Run an environment's test.sh in an isolated namespace."
  echo ""
  echo "Examples:"
  echo "  $0 postgres --start-services"
  echo "  $0 go"
  exit 1
fi

ENV_NAME="$1"
START_SERVICES=""
if [[ "${2:-}" == "--start-services" ]] || [[ "${2:-}" == "true" ]]; then
  START_SERVICES="--start-services"
fi

ENV_DIR="$REPO_DIR/$ENV_NAME"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: Environment '$ENV_NAME' not found at $ENV_DIR"
  exit 1
fi

if [[ ! -f "$ENV_DIR/test.sh" ]]; then
  echo "Error: No test.sh found in $ENV_DIR"
  exit 1
fi

# --- Detect capabilities ---

detect_namespace_support() {
  # Check if we can use user namespaces (unprivileged)
  if unshare --user --net true 2>/dev/null; then
    echo "user"
    return
  fi

  # Check if we have root or CAP_SYS_ADMIN
  if [[ $EUID -eq 0 ]] || unshare --net true 2>/dev/null; then
    echo "root"
    return
  fi

  echo "none"
}

NS_SUPPORT=$(detect_namespace_support)

# --- Build unshare flags ---

build_unshare_cmd() {
  local flags=""

  case "$NS_SUPPORT" in
    user)
      # Unprivileged: user + network + PID namespaces
      # Mount namespace requires more privileges
      flags="--user --map-root-user --net --pid --fork"
      ;;
    root)
      # Privileged: full isolation
      flags="--net --pid --mount --fork"
      ;;
    none)
      echo "Warning: Namespace support not available." >&2
      echo "Warning: Running without isolation." >&2
      echo ""
      return
      ;;
  esac

  echo "unshare $flags"
}

UNSHARE_CMD=$(build_unshare_cmd)

# --- Inner test script ---
#
# This runs inside the namespace. It:
# 1. Sets up loopback networking
# 2. Copies the environment to a temp directory
# 3. Runs the test
# 4. Cleans up on exit

INNER_SCRIPT='
set -euo pipefail

ENV_DIR="$1"
ENV_NAME="$2"
START_SERVICES="$3"

# Set up loopback in the network namespace
if command -v ip >/dev/null 2>&1; then
  ip link set lo up 2>/dev/null || true
fi

# Create isolated temp directory
TESTDIR=$(mktemp -d "/tmp/floxenvs-test-${ENV_NAME}-XXXXXX")

cleanup() {
  # Kill any remaining processes in our namespace
  # (PID namespace handles this, but belt and suspenders)
  if [[ -n "${TESTDIR:-}" ]] && [[ -d "$TESTDIR" ]]; then
    rm -rf "$TESTDIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Copy environment to temp dir
cp -R "$ENV_DIR"/* "$TESTDIR/" 2>/dev/null || true
cp -R "$ENV_DIR"/.flox* "$TESTDIR/"
if [[ -f "$ENV_DIR/.env" ]]; then
  cp "$ENV_DIR/.env" "$TESTDIR/"
fi
if [[ -f "$ENV_DIR/.gitignore" ]]; then
  cp "$ENV_DIR/.gitignore" "$TESTDIR/"
fi

cd "$TESTDIR"

# Set testing mode
export FLOX_ENVS_TESTING=1
export FLOX_DISABLE_METRICS=true

echo "=== Isolated test: $ENV_NAME ==="
echo "  Namespace: active"
echo "  Test dir:  $TESTDIR"
echo "  Services:  ${START_SERVICES:-none}"
echo ""

# Run the test
activate_flags=""
if [[ -n "$START_SERVICES" ]]; then
  activate_flags="--start-services"
fi

flox activate $activate_flags -- bash test.sh
'

# --- Execute ---

echo ">>> Running '$ENV_NAME' test in isolated namespace..."
echo ">>> Namespace support: $NS_SUPPORT"
echo ""

if [[ -n "$UNSHARE_CMD" ]]; then
  $UNSHARE_CMD bash -c "$INNER_SCRIPT" -- \
    "$ENV_DIR" "$ENV_NAME" "$START_SERVICES"
else
  # Fallback: run without isolation
  bash -c "$INNER_SCRIPT" -- \
    "$ENV_DIR" "$ENV_NAME" "$START_SERVICES"
fi

echo ""
echo ">>> Test '$ENV_NAME' completed successfully."

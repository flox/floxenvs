#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists localstack
command_exists aws
command_exists kubectl
command_exists gum

# ── Debug: Docker environment ─────────────────────────
echo ">>> Docker diagnostics:"
echo "  which docker: $(which docker 2>&1 || echo NOT_FOUND)"
echo "  docker sock:  $(ls -la /var/run/docker.sock 2>&1 || echo NO_SOCK)"
echo "  docker info:"
docker info 2>&1 | head -20 || echo "  docker info FAILED"
echo ""
echo "  docker ps:"
docker ps 2>&1 || echo "  docker ps FAILED"
echo ""

# ── Debug: LocalStack config ─────────────────────────
echo ">>> LocalStack environment:"
echo "  LOCALSTACK_CACHE: ${LOCALSTACK_CACHE:-unset}"
echo "  LOCALSTACK_HOST:  ${LOCALSTACK_HOST:-unset}"
echo "  LOCALSTACK_VOLUME_DIR: ${LOCALSTACK_VOLUME_DIR:-unset}"
echo "  DEBUG:            ${DEBUG:-unset}"
echo "  DOCKER_HOST:      ${DOCKER_HOST:-unset}"
echo ""

# ── Debug: flox services ──────────────────────────────
echo ">>> flox services status (before wait loop):"
flox services status 2>&1 || echo "  flox services status FAILED"
echo ""
echo ">>> flox services logs localstack (before wait loop):"
flox services logs localstack 2>&1 || echo "  no logs yet"
echo ""

# ── Debug: try localstack status directly ─────────────
echo ">>> localstack status (before wait loop):"
localstack status 2>&1 || echo "  localstack status FAILED"
echo ""

# ── Wait for LocalStack ──────────────────────────────
echo ">>> Waiting for LocalStack to start (max 180s) .."
MAX_ATTEMPTS=90
ATTEMPT=0
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  ATTEMPT=$((ATTEMPT + 1))
  status_out="$(localstack status 2>&1 || true)"
  if echo "$status_out" | grep -q running; then
    echo ""
    echo ">>> LocalStack STARTED SUCCESSFULLY (attempt $ATTEMPT)"
    echo ""
    break
  fi
  # Print status every 10 attempts for debugging
  if [ $((ATTEMPT % 10)) -eq 0 ]; then
    echo ""
    echo ">>> Still waiting (attempt $ATTEMPT/90)..."
    echo "  localstack status: $status_out"
    echo "  docker ps:"
    docker ps 2>&1 || true
    echo "  flox services logs (last 5 lines):"
    flox services logs localstack 2>&1 | tail -5 || true
  else
    echo -n ".."
  fi
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 2
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo ""
  echo ">>> FAILURE: LocalStack not ready after 180 seconds"
  echo ""
  echo ">>> Final diagnostics:"
  echo "  localstack status:"
  localstack status 2>&1 || true
  echo ""
  echo "  docker ps -a (all containers):"
  docker ps -a 2>&1 || true
  echo ""
  echo "  flox services status:"
  flox services status 2>&1 || true
  echo ""
  echo "  flox services logs localstack (full):"
  flox services logs localstack 2>&1 || true
  echo ""
  echo "  docker logs (localstack container):"
  docker logs "$(docker ps -aq --filter name=localstack 2>/dev/null | head -1)" 2>&1 || echo "  no container found"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs localstack"
flox services logs localstack

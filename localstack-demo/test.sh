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

# Remove stale LocalStack container if left over from a
# previous CI run (macOS Colima keeps containers across
# jobs). The service command also does this, but belt and
# suspenders.
if docker ps -a --format '{{.Names}}' 2>/dev/null \
    | grep -q localstack; then
  echo ">>> Removing stale LocalStack container..."
  docker rm -f localstack-main 2>/dev/null || true
fi

echo -n ">>> Waiting for LocalStack to start .."
MAX_ATTEMPTS=30
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if localstack status | grep -q running 2>/dev/null; then
    echo -e "\n>>> LocalStack STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 2
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: LocalStack not ready after 60 seconds"
  echo ""
  echo ">>> Diagnostics:"
  localstack status 2>&1 || true
  docker ps -a 2>&1 || true
  flox services status 2>&1 || true
  flox services logs localstack 2>&1 || true
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs localstack"
flox services logs localstack

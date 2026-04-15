#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

echo ">>> DEBUG PATH: $PATH"
echo ">>> DEBUG which docker: $(which docker 2>&1 || echo NOT_FOUND)"
echo ">>> DEBUG docker sock: $(ls -la /var/run/docker.sock 2>&1 || echo NO_SOCK)"

command_exists localstack
command_exists aws
command_exists kubectl
command_exists gum

echo -n ">>> Waiting for LocalStack to start .."
MAX_ATTEMPTS=60
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
  echo -e "\nError: LocalStack not ready after 120 seconds"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs localstack"
flox services logs localstack

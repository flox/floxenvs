#!/usr/bin/env bash

set -eo pipefail

if ! command -v temporal >/dev/null 2>&1; then
  echo "Error: 'temporal' command not found."
  exit 1
fi

echo -n ">>> Waiting for Temporal to start .."
MAX_ATTEMPTS=30
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if (echo > /dev/tcp/$TEMPORAL_HOST/$TEMPORAL_PORT) \
      2>/dev/null; then
    echo -e "\n>>> Temporal STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: Temporal not ready after 30 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs temporal"
flox services logs temporal

echo ">>> Checking Temporal namespace list..."
temporal operator namespace list \
  --address "$TEMPORAL_HOST:$TEMPORAL_PORT"
echo ">>> Temporal namespace list ... OK"

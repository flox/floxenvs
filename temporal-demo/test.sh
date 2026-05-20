#!/usr/bin/env bash

set -eo pipefail

if ! command -v temporal >/dev/null 2>&1; then
  echo "Error: 'temporal' command not found."
  exit 1
fi
if ! command -v go >/dev/null 2>&1; then
  echo "Error: 'go' command not found."
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' command not found."
  exit 1
fi

echo -n ">>> Waiting for Temporal to start .."
MAX_ATTEMPTS=30
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if temporal operator namespace list \
      --address "$TEMPORAL_HOST:$TEMPORAL_PORT" \
      >/dev/null 2>&1; then
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

echo ">>> Waiting for worker to poll my-task-queue .."
MAX_ATTEMPTS=60
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  pollers=$(temporal task-queue describe \
      --task-queue my-task-queue \
      --address "$TEMPORAL_HOST:$TEMPORAL_PORT" \
      -o json 2>/dev/null \
    | jq -r '[.pollers[]?] | length' 2>/dev/null \
    || echo 0)
  if [ "${pollers:-0}" -gt 0 ]; then
    echo ">>> Worker is polling ($pollers) ... OK"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo "Error: Worker never started"
  flox services logs worker | tail -20
  exit 1
fi

echo ">>> Running starter ..."
out=$(go run ./start TestUser 2>&1)
echo "$out"

if echo "$out" | grep -q "Workflow result: Hello TestUser"; then
  echo ">>> Workflow returned 'Hello TestUser' ... OK"
else
  echo "Error: expected 'Hello TestUser' in starter output"
  exit 1
fi

echo ">>> Checking Temporal Web UI port..."
if (echo > /dev/tcp/$TEMPORAL_HOST/$TEMPORAL_UI_PORT) \
    2>/dev/null; then
  echo ">>> Temporal Web UI is accessible ... OK"
else
  echo "Warning: Web UI port not responding"
fi

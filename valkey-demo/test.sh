#!/usr/bin/env bash

set -eo pipefail

if ! command -v valkey-cli >/dev/null 2>&1; then
  echo "Error: 'valkey-cli' command not found."
  exit 1
fi

echo -n ">>> Waiting for Valkey to start .."
MAX_ATTEMPTS=20
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT" ping \
      2>/dev/null | grep -q PONG; then
    echo -e "\n>>> Valkey STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: Valkey not ready after 20 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs valkey"
flox services logs valkey

echo ">>> Testing SET/GET/DEL operations..."
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT" SET flox_test "hello"
RESULT=$(valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT" GET flox_test)
if [ "$RESULT" != "hello" ]; then
  echo "Error: GET returned '$RESULT', expected 'hello'"
  exit 1
fi
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT" DEL flox_test
echo ">>> SET/GET/DEL operations ... OK"

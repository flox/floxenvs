#!/usr/bin/env bash

set -euo pipefail

if ! command -v nginx 2>&1 >/dev/null; then
  echo "Error: 'nginx' command could not be found."
  exit 1
fi
if ! command -v curl 2>&1 >/dev/null; then
  echo "Error: 'curl' command could not be found."
  exit 1
fi

echo -n "Waiting for Nginx to start .."
MAX_ATTEMPTS=20
while [[ "$MAX_ATTEMPTS" != "0" ]]; do
  if curl -sf http://localhost:$NGINX_PORT >/dev/null 2>&1; then
    echo ""
    break
  fi
  echo -n ".."
  sleep 1
  MAX_ATTEMPTS=$((MAX_ATTEMPTS-1))
done

if [[ "$MAX_ATTEMPTS" == "0" ]]; then
  echo ""
  echo "Error: Nginx did not start in time."
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs nginx"
flox services logs nginx

BODY=$(curl -s http://localhost:$NGINX_PORT)
if echo "$BODY" | grep -q "Hello Flox"; then
  echo ">>> Nginx is serving correctly."
else
  echo "Error: unexpected response from Nginx."
  exit 1
fi

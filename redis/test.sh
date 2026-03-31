#!/usr/bin/env bash

set -eo pipefail

if ! command -v redis-cli >/dev/null 2>&1; then
  echo "Error: 'redis-cli' command not found."
  exit 1
fi

echo -n ">>> Waiting for Redis to start .."
MAX_ATTEMPTS=20
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping \
      2>/dev/null | grep -q PONG; then
    echo -e "\n>>> Redis STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: Redis not ready after 20 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs redis"
flox services logs redis

echo ">>> Redis is running on $REDIS_HOST:$REDIS_PORT"

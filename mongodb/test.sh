#!/usr/bin/env bash

set -eo pipefail

if ! command -v mongod >/dev/null 2>&1; then
  echo "Error: 'mongod' command not found."
  exit 1
fi

echo -n ">>> Waiting for MongoDB to start .."
MAX_ATTEMPTS=20
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if (echo > /dev/tcp/$MONGO_HOST/$MONGO_PORT) \
      2>/dev/null; then
    echo -e "\n>>> MongoDB STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: MongoDB not ready after 20 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs mongodb"
flox services logs mongodb

echo ">>> MongoDB is running on $MONGO_HOST:$MONGO_PORT"

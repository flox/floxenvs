#!/usr/bin/env bash

set -eo pipefail

if ! command -v mongod 2>&1 >/dev/null; then
  echo "Error: 'mongod' command could not be found."
  exit 1
fi
if ! command -v mongosh 2>&1 >/dev/null; then
  echo "Error: 'mongosh' command could not be found."
  exit 1
fi

MAX_ATTEMPTS=20
echo -n ">>> Waiting for MongoDB to start .."
while [ $MAX_ATTEMPTS -gt 0 ]; do
  if mongosh --host $MONGO_HOST --port $MONGO_PORT --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo -e "\n>>> MongoDB STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS-1))
  sleep 1
done

if [ $MAX_ATTEMPTS -eq 0 ]; then
  echo -e "\nError: Failed to connect to MongoDB after 20 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs monogodb"
flox services logs mongodb

MONGO_STATUS=$(mongosh --host $MONGO_HOST --port $MONGO_PORT --eval "db.serverStatus().ok" --quiet)
if [ "$MONGO_STATUS" != "1" ]; then
    echo "Error: MongoDB is not responding correctly."
    exit 1
fi
echo ">>> MongoDB server status check ... OK"

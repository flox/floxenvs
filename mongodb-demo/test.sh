#!/usr/bin/env bash

set -eo pipefail

if ! command -v mongod >/dev/null 2>&1; then
  echo "Error: 'mongod' command not found."
  exit 1
fi
if ! command -v mongosh >/dev/null 2>&1; then
  echo "Error: 'mongosh' command not found."
  exit 1
fi

echo -n ">>> Waiting for MongoDB to start .."
MAX_ATTEMPTS=20
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if mongosh --host "$MONGO_HOST" \
      --port "$MONGO_PORT" \
      --eval "db.adminCommand('ping')" \
      >/dev/null 2>&1; then
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

MONGO_STATUS=$(mongosh --host "$MONGO_HOST" \
  --port "$MONGO_PORT" \
  --eval "db.serverStatus().ok" --quiet 2>&1 \
  || true)
MONGO_STATUS=$(echo "$MONGO_STATUS" | tail -1 | tr -d '[:space:]')
if [ "$MONGO_STATUS" != "1" ]; then
  echo "Error: MongoDB not responding correctly (got: '$MONGO_STATUS')."
  exit 1
fi
echo ">>> MongoDB server status check ... OK"

echo ">>> Testing CRUD operations..."
mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" \
  --quiet --eval '
  use("flox_test");
  db.items.drop();
  db.items.insertOne({name: "test", value: 42});
  const doc = db.items.findOne({name: "test"});
  assert(doc !== null, "Insert/find failed");
  assert(doc.value === 42, "Value mismatch");
  db.items.drop();
  print("CRUD test passed");
'
echo ">>> CRUD operations ... OK"

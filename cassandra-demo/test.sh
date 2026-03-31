#!/usr/bin/env bash

set -eo pipefail

if ! command -v cqlsh >/dev/null 2>&1; then
  echo "Error: 'cqlsh' command not found."
  exit 1
fi
if ! command -v nodetool >/dev/null 2>&1; then
  echo "Error: 'nodetool' command not found."
  exit 1
fi

echo -n ">>> Waiting for Cassandra to start .."
MAX_ATTEMPTS=60
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if nodetool status >/dev/null 2>&1; then
    echo -e "\n>>> Cassandra STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: Cassandra not ready after 60 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs cassandra"
flox services logs cassandra

echo ">>> Testing CQL operations..."
cqlsh "$CASSANDRA_HOST" "$CASSANDRA_PORT" -e \
  "CREATE KEYSPACE IF NOT EXISTS flox_test
    WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
  USE flox_test;
  CREATE TABLE IF NOT EXISTS items (id UUID PRIMARY KEY, name text, value int);
  INSERT INTO items (id, name, value) VALUES (uuid(), 'test', 42);
  SELECT * FROM items WHERE name = 'test' ALLOW FILTERING;
  DROP KEYSPACE flox_test;"
echo ">>> CQL operations ... OK"

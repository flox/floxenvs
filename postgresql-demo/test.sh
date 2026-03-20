#!/usr/bin/env bash

set -euo pipefail

if ! command -v psql 2>&1 >/dev/null; then
  echo "Error: 'psql' command could not be found."
  exit 1
fi
if ! command -v pg_isready 2>&1 >/dev/null; then
  echo "Error: 'pg_isready' command could not be found."
  exit 1
fi

echo -n "Waiting for PostgreSQL to start .."
MAX_ATTEMPTS=20
while [[ "$MAX_ATTEMPTS" != "0" ]]; do
  if pg_isready -q 2>/dev/null; then
    echo ""
    break
  fi
  echo -n ".."
  sleep 1
  MAX_ATTEMPTS=$((MAX_ATTEMPTS-1))
done

if [[ "$MAX_ATTEMPTS" == "0" ]]; then
  echo ""
  echo "Error: PostgreSQL did not start in time."
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs postgres"
flox services logs postgres

if psql -c "SELECT 1;"; then
  echo
  echo ">>> PostgreSQL is running."
else
  echo "Error: Something went wrong."
  exit 1
fi

echo ">>> Testing pgvector extension"
psql -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -c "CREATE TABLE IF NOT EXISTS items (id bigserial PRIMARY KEY, embedding vector(3));"
psql -c "INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');"
psql -c "SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;"
echo ">>> pgvector working."

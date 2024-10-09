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
  set +e
  PG_STATUS=$(pg_isready)
  set -e
  if [[ "$PG_STATUS" == "$PGHOSTADDR:$PGPORT - accepting connections" ]]; then
    echo -n "\n"
    break
  fi
  echo -n ".."
  sleep 1
  MAX_ATTEMPTS=$((MAX_ATTEMPTS-1))
done

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

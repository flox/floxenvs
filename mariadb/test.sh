#!/usr/bin/env bash

set -eo pipefail

if ! command -v mariadb >/dev/null 2>&1; then
  echo "Error: 'mariadb' command not found."
  exit 1
fi
if ! command -v mariadb-admin >/dev/null 2>&1; then
  echo "Error: 'mariadb-admin' command not found."
  exit 1
fi

echo -n ">>> Waiting for MariaDB to start .."
MAX_ATTEMPTS=20
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if mariadb-admin \
      --socket="$MARIADB_SOCKET" \
      ping -u root 2>/dev/null | grep -q alive; then
    echo -e "\n>>> MariaDB STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: MariaDB not ready after 20 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs mariadb"
flox services logs mariadb

RESULT=$(mariadb --socket="$MARIADB_SOCKET" \
  -u "$MARIADB_USER" -p"$MARIADB_PWD" -sN -e "SELECT 1")
if [ "$RESULT" != "1" ]; then
  echo "Error: SELECT 1 returned '$RESULT'"
  exit 1
fi
echo ">>> MariaDB SELECT 1 ... OK"

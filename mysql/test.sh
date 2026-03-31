#!/usr/bin/env bash

set -eo pipefail

if ! command -v mysql >/dev/null 2>&1; then
  echo "Error: 'mysql' command not found."
  exit 1
fi
if ! command -v mysqladmin >/dev/null 2>&1; then
  echo "Error: 'mysqladmin' command not found."
  exit 1
fi

echo -n ">>> Waiting for MySQL to start .."
MAX_ATTEMPTS=20
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if mysqladmin ping 2>/dev/null | grep -q alive; then
    echo -e "\n>>> MySQL STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: MySQL not ready after 20 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs mysql"
flox services logs mysql

RESULT=$(mysql -sN -e "SELECT 1")
if [ "$RESULT" != "1" ]; then
  echo "Error: SELECT 1 returned '$RESULT'"
  exit 1
fi
echo ">>> MySQL SELECT 1 ... OK"

#!/usr/bin/env bash

set -eo pipefail

if ! command -v mysql 2>&1 >/dev/null
then
    echo "Error: 'mysql' command could not be found."
    exit 1
fi
if ! command -v mysqladmin 2>&1 >/dev/null
then
    echo "Error: 'mysqladmin' command could not be found."
    exit 1
fi

echo -n "Waiting for MySQL to come up ..."
MAX_ATTEMPTS=10
while [ $MAX_ATTEMPTS -gt 0 ]; do
  set +e
  MYSQL_STATUS=$(mysqladmin ping 2>&1)
  set -e
  if [ "$MYSQL_STATUS" == "mysqld is alive" ]; then
    break
  fi
  echo -n ".."
  sleep 1
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
done
if [ $MAX_ATTEMPTS -eq 0 ]; then
  echo ""
  echo "❌ Error: MySQL didn't come up in time."
  exit 1
fi
echo ""
echo "✅ MySQL service is up."
mysqladmin ping -u root --silent

echo ">>> flox services status"
flox services status

echo ">>> flox services logs mysql"
flox services logs mysql

echo ">>> Run 'SELECT 1' query."
mysql -sN -e "SELECT 1"
RESULT=$(mysql -sN -e "SELECT 1")
echo "RESULT: $RESULT"
if [[ "$RESULT" != "1" ]]; then
  echo "Error: Something wrong!."
  exit 1
fi
echo ">>> MySQL connection test passed."

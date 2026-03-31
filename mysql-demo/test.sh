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

echo ">>> Testing CRUD operations..."
mysql -e "CREATE TABLE IF NOT EXISTS $MYSQL_DATABASE.flox_test (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50));"
mysql -e "INSERT INTO $MYSQL_DATABASE.flox_test (name) VALUES ('hello');"
CRUD_RESULT=$(mysql -sN -e "SELECT name FROM $MYSQL_DATABASE.flox_test WHERE name='hello' LIMIT 1;")
if [ "$CRUD_RESULT" != "hello" ]; then
  echo "Error: CRUD test failed, got '$CRUD_RESULT'"
  exit 1
fi
mysql -e "DROP TABLE $MYSQL_DATABASE.flox_test;"
echo ">>> CRUD operations ... OK"

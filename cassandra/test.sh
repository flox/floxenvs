#!/usr/bin/env bash

set -eo pipefail

if ! command -v cqlsh 2>&1 >/dev/null
then
    echo "Error: 'cqlsh' command could not be found."
    exit 1
fi

if ! command -v nodetool 2>&1 >/dev/null
then
    echo "Error: 'nodetool' command could not be found."
    exit 1
fi

is_cassandra_up() {
    nodetool status > /dev/null 2>&1
}

# Wait until Cassandra is up
echo -n "Waiting for Cassandra to start .."
until is_cassandra_up; do
    echo -n ".."
    sleep 1
done
echo -n "\n"


echo ">>> flox services status"
flox services status

echo ">>> flox services logs cassandra"
flox services logs cassandra

if cqlsh -e "SELECT now() FROM system.local;" $CASSANDRA_HOST $CASSANDRA_PORT; then
  echo
  echo ">>> Cassandra is running."
else
  echo "Error: Something went wrong."
  exit 1
fi

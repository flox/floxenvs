#!/usr/bin/env bash

set -eo pipefail

echo -n ">>> Waiting for Elasticsearch to start .."
until [[ "$(curl -s http://$ES_ADDR:$ES_PORT/_cluster/health | jq -r '.status')" == "green" ]]; do
  echo -n ".."
  sleep 1
done
echo -n " STARTED\n"

echo ">>> flox services status"
flox services status

echo ">>> flox services logs elasticsearch"
flox services logs elasticsearch

CLUSTER_NAME=$(curl -fsk http://$ES_ADDR:$ES_PORT | jq -r '.cluster_name' | xargs)
if [ "$CLUSTER_NAME" != "elasticsearch" ]; then
    echo "Error: Something went wrong."
    exit 1
fi
echo ">>> Elasticsearch cluster name is ... $CLUSTER_NAME"

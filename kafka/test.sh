#!/usr/bin/env bash

set -eo pipefail

if ! command -v kafka-topics.sh >/dev/null 2>&1; then
  echo "Error: 'kafka-topics.sh' command not found."
  exit 1
fi

echo -n ">>> Waiting for Kafka to start .."
MAX_ATTEMPTS=60
while [ "$MAX_ATTEMPTS" -gt 0 ]; do
  if kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --list >/dev/null 2>&1; then
    echo -e "\n>>> Kafka STARTED SUCCESSFULLY\n"
    break
  fi
  echo -n ".."
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
  sleep 1
done

if [ "$MAX_ATTEMPTS" -eq 0 ]; then
  echo -e "\nError: Kafka not ready after 60 attempts"
  exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs kafka"
flox services logs kafka

echo ">>> Creating a test topic..."
kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" \
  --create --if-not-exists --topic flox-test --partitions 1 --replication-factor 1
kafka-topics.sh --bootstrap-server "$KAFKA_BROKERS" --list | grep -q flox-test
echo ">>> Kafka topic check ... OK"

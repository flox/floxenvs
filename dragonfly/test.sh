#!/usr/bin/env bash

set -eo pipefail

if ! command -v redis-cli 2>&1 >/dev/null
then
    echo "Error: 'redis-cli' command could not be found."
    exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs dragonfly"
flox services logs dragonfly

PONG=$(redis-cli -p $DRAGONFLY_PORT ping)
if [ "$PONG" != "PONG" ]; then
    echo "Error: 'redis-cli' PONG not returned."
    exit 1
fi
echo ">>> redis-cli -p $DRAGONFLY_PORT ping ... $PONG"

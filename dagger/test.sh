#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v $1 2>&1 >/dev/null; then
    echo "Error: '$1' command could not be found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists dagger

is_dagger_engine_up() {
  if [ "$( docker container inspect -f '{{.State.Running}}' $DAGGER_ENGINE_NAME)" = "true" ]; then
    return 0
  else
    return 1
  fi
}

echo -n ">>> Waiting for Dagger Engine to start (it make take some time) .."
MAX_ATTEMPTS=300  # 5min in case it needs to download the image
until is_dagger_engine_up; do
    if [ $MAX_ATTEMPTS -le 0 ]; then
        echo -n "Ran out of attempts!"
        echo "❌ Error: Dagger Engine didn't come up in time."
        exit 1
    fi
    echo -n "."
    sleep 1
    MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
done
echo -n " ✅ IS UP!\n"

echo ">>> flox services status"
flox services status

echo ">>> flox services logs dagger-engine"
flox services logs dagger-engine

dagger call container-echo --string-arg="WORKS" stdout
echo ">>> Dagger works"

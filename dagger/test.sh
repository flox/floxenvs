#!/usr/bin/env bash

set -eo pipefail

if ! command -v dagger 2>&1 >/dev/null
then
    echo "Error: 'dagger' command could not be found."
    exit 1
fi

echo ">>> flox services status"
flox services status

echo ">>> flox services logs dagger-engine"
flox services logs dagger-engine

dagger call container-echo --string-arg="WORKS"
echo ">>> Dagger works"

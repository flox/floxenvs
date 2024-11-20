#!/usr/bin/env bash

set -eo pipefail

check_command() {
    if ! command -v $1 2>&1 >/dev/null
    then
        echo "Error: '$1' command could not be found."
        exit 1
    fi
}

check_command node
check_command npm


node --eval "require('figlet')"
echo ">>> figlet package installed"

node index.js
echo ">>> script works"


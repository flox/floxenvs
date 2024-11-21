#!/usr/bin/env bash

set -eo pipefail

check_command() {
    if ! command -v $1 2>&1 >/dev/null
    then
        echo "Error: '$1' command could not be found."
        exit 1
    fi
}

check_command deno


deno repl --eval "import figlet from 'figlet'; close()"
echo ">>> figlet package installed"

deno run --allow-all --no-prompt main.ts
echo ">>> script works"


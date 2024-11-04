#!/usr/bin/env bash

set -eo pipefail

check_command() {
    if ! command -v $1 2>&1 >/dev/null
    then
        echo "Error: '$1' command could not be found."
        exit 1
    fi
}

check_command python
check_command poetry
check_command pyjokes

python -c "import pyjokes"
echo ">>> pyjokes python package installed"

pyjokes
echo ">>> pyjokes binary works"


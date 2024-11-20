#!/usr/bin/env bash

set -eo pipefail

check_command() {
    if ! command -v $1 2>&1 >/dev/null
    then
        echo "Error: '$1' command could not be found."
        exit 1
    fi
}

check_command mkcert

if [ ! -f "$CAROOT/rootCA.pem" ]; then exit 1; fi
if [ ! -f "$CAROOT/domains.pem" ]; then exit 1; fi
if [ ! -f "$CAROOT/domains-key.pem" ]; then exit 1; fi

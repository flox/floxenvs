#!/usr/bin/env bash

set -eo pipefail

check_command() {
    if ! command -v $1 2>&1 >/dev/null
    then
        echo "Error: '$1' command could not be found."
        exit 1
    fi
}

check_command qmk


qmk clone
echo ">>> QMK firmware cloned"

qmk setup -H $PWD/qmk_firmware --yes
echo ">>> QMK firmware setup"

qmk compile -kb clueboard/66/rev3 -km default
echo ">>> QMK firmware compiled"

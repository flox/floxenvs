#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" != 'Linux' ]; then
  echo "Skipping; the podman test should only be run on Linux"
  exit 0
fi

RESULT="$(podman run -it quay.io/podman/hello)"
echo "RESULT: $RESULT"
if [[ "$RESULT" != *"... Hello Podman World ..."* ]]; then
  echo "Error: Something went wrong!"
  exit 1
fi

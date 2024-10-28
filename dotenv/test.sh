#!/usr/bin/env bash

set -eo pipefail

MULTILINE_TEST=$(echo -e "ONE\nTWO\nTHREE")

if [ "$PING" != "PONG" ]; then exit 1; fi
if [ "$MULTILINE" != "$(echo -e 'ONE\nTWO\nTHREE')" ]; then exit 1; fi
if [ "$SECRET_KEY" != "YOURSECRETKEYGOESHERE" ];  then exit 1; fi
if [ "$SECRET_HASH" != "something-with-a-#-hash" ];  then exit 1; fi

echo ">>> All tests pass"

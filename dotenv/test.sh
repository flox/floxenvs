#!/usr/bin/env bash

set -eo pipefail

MULTILINE_TEST=$(echo -e "ONE\nTWO\nTHREE")

if [ "$PING" != "PONG" ]; then
  echo "Error: ping poing failed"
  echo "  Left  -> $PING"
  echo "  Right -> PONG"
  exit 1
fi

if [ "$MULTILINE" != "$(echo -e 'ONE\nTWO\nTHREE')" ]; then
  echo "Error: multiline failed"
  echo "  Left  -> $MULTILINE"
  echo "  Right -> $(echo -e 'ONE\nTWO\nTHREE')"
  exit 1
fi

if [ "$SECRET_KEY" != "YOURSECRETKEYGOESHERE" ];  then
  echo "Error: secret key failed"
  echo "  Left  -> $SECRET_KEY"
  echo "  Right -> YOURSECRETKEY"
  exit 1
fi

if [ "$SECRET_HASH" != "something-with-a-#-hash" ];  then
  echo "Error: secret hash failed"
  echo "  Left  -> $SECRET_HASH"
  echo "  Right -> something-with-a-#-hash"
  exit 1
fi

echo ">>> All tests pass"

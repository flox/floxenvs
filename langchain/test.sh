#!/usr/bin/env bash

set -euo pipefail

echo ">>> flox services status"
flox services status

echo ">>> flox services logs ollama"
flox services logs ollama

if ! command -v $FLOX_ENV/bin/python3 test.py 2>&1 >/dev/null; then
  echo "Error: 'test.py' did not return successfully"
  exit 1
fi


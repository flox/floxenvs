#!/usr/bin/env bash

set -eo pipefail

if ! command -v mkcert >/dev/null 2>&1; then
  echo "Error: 'mkcert' command not found."
  exit 1
fi

echo ">>> mkcert version: $(mkcert --version 2>&1 || echo unknown)"

# Verify CA and certs were created
if [ ! -f "$CAROOT/rootCA.pem" ]; then
  echo "Error: Root CA not created at $CAROOT/rootCA.pem"
  exit 1
fi
echo ">>> Root CA exists: $CAROOT/rootCA.pem"

if [ ! -f "$CAROOT/domains.pem" ]; then
  echo "Error: Domain cert not created"
  exit 1
fi
echo ">>> Domain cert exists: $CAROOT/domains.pem"

if [ ! -f "$CAROOT/domains-key.pem" ]; then
  echo "Error: Domain key not created"
  exit 1
fi
echo ">>> Domain key exists: $CAROOT/domains-key.pem"

echo ">>> mkcert environment is working"

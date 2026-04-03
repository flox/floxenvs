#!/usr/bin/env bash

set -eo pipefail

if ! command -v mkcert >/dev/null 2>&1; then
  echo "Error: 'mkcert' command not found."
  exit 1
fi

echo ">>> mkcert version: $(mkcert --version 2>&1 || echo unknown)"

# Verify certs from base layer
if [ ! -f "$CAROOT/rootCA.pem" ]; then
  echo "Error: Root CA not created"
  exit 1
fi
echo ">>> Root CA: $CAROOT/rootCA.pem"

if [ ! -f "$CAROOT/domains.pem" ]; then
  echo "Error: Domain cert not created"
  exit 1
fi
echo ">>> Domain cert: $CAROOT/domains.pem"

# Verify NODE_EXTRA_CA_CERTS is set
if [ -z "$NODE_EXTRA_CA_CERTS" ]; then
  echo "Error: NODE_EXTRA_CA_CERTS not set"
  exit 1
fi
echo ">>> NODE_EXTRA_CA_CERTS=$NODE_EXTRA_CA_CERTS"

echo ">>> mkcert-demo environment is working"

#!/usr/bin/env bash

set -eo pipefail

# Create a temporary .env for testing
cat > .env << 'EOF'
PING=PONG
SECRET_KEY=YOURSECRETKEYGOESHERE
SECRET_HASH="something-with-a-#-hash"
EOF

# Re-source the hook to load .env
set -o allexport
source .env
set +o allexport

if [ "$PING" != "PONG" ]; then
  echo "Error: PING != PONG (got: '$PING')"
  exit 1
fi

if [ "$SECRET_KEY" != "YOURSECRETKEYGOESHERE" ]; then
  echo "Error: SECRET_KEY mismatch"
  exit 1
fi

echo ">>> dotenv environment is working"

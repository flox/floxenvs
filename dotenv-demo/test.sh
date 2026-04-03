#!/usr/bin/env bash

set -eo pipefail

if [ "$APP_NAME" != "MyFloxApp" ]; then
  echo "Error: APP_NAME not loaded (got: '$APP_NAME')"
  exit 1
fi

if [ "$APP_PORT" != "3000" ]; then
  echo "Error: APP_PORT not loaded (got: '$APP_PORT')"
  exit 1
fi

if [ "$SECRET_KEY" != "demo-secret-key-change-me" ]; then
  echo "Error: SECRET_KEY not loaded (got: '$SECRET_KEY')"
  exit 1
fi

echo ">>> Variables loaded from .env:"
echo "    APP_NAME=$APP_NAME"
echo "    APP_PORT=$APP_PORT"
echo "    DEBUG=$DEBUG"
echo ">>> dotenv-demo environment is working"

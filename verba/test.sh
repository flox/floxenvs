#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v weaviate >/dev/null 2>&1; then
  echo "Error: 'weaviate' command not found."
  exit 1
fi
if ! command -v ollama >/dev/null 2>&1; then
  echo "Error: 'ollama' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> weaviate available"
echo ">>> ollama version: $(ollama --version 2>&1 | head -1)"

echo ">>> verba environment is working"

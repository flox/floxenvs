#!/usr/bin/env bash

set -eo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "Error: 'ollama' command not found."
  exit 1
fi
echo ">>> ollama ... OK"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
echo ">>> python3 ... OK"

echo ">>> Checking Python imports..."
python3 -c "import langgraph" || { echo "Error: failed to import langgraph"; exit 1; }
echo ">>>   langgraph ... OK"

python3 -c "import langchain_ollama" || { echo "Error: failed to import langchain_ollama"; exit 1; }
echo ">>>   langchain_ollama ... OK"

python3 -c "import langchain_community" || { echo "Error: failed to import langchain_community"; exit 1; }
echo ">>>   langchain_community ... OK"

echo ">>> All checks passed."

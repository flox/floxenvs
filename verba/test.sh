#!/usr/bin/env bash

set -eo pipefail

check_command() {
	if ! command -v $1 2>&1 >/dev/null; then
		echo "Error: '$1' command could not be found."
		exit 1
	fi
}

check_command weaviate
check_command ollama
check_command "$PYTHON_DIR/bin/verba"

echo "All commands are on \$PATH."

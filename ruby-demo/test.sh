#!/usr/bin/env bash

set -eo pipefail

if ! command -v ruby >/dev/null 2>&1; then
  echo "Error: 'ruby' command not found."
  exit 1
fi
if ! command -v bundle >/dev/null 2>&1; then
  echo "Error: 'bundle' command not found."
  exit 1
fi

echo ">>> ruby version: $(ruby --version)"
echo ">>> bundler version: $(bundle --version)"

# Verify colorize gem installed
if [ -f Gemfile ]; then
  echo ">>> Verifying gems..."
  bundle exec ruby -e "require 'colorize'; puts 'colorize loaded OK'"
  echo ">>> Gem import ... OK"
fi

# Run sample script
if [ -f test.rb ]; then
  bundle exec ruby test.rb
  echo ">>> test.rb ... OK"
fi

echo ">>> ruby-demo environment is working"

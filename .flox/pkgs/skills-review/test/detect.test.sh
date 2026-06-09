#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/lib/detect.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/sk"; printf -- '---\nname: x\ndescription: y\n---\n' > "$tmp/sk/SKILL.md"
[ "$(detect_kind "$tmp/sk")" = "skill" ] || { echo "FAIL skill"; exit 1; }

printf -- '---\nname: a\ndescription: d\nmodel: sonnet\ntools: Read\n---\n' > "$tmp/ag.md"
[ "$(detect_kind "$tmp/ag.md")" = "agent" ] || { echo "FAIL agent"; exit 1; }
echo "PASS detect"

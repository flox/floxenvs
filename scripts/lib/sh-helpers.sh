#!/usr/bin/env bash
# Tiny helpers shared across audit scripts.
#
# Source from another script with:
#   . "$(dirname "$0")/lib/sh-helpers.sh"
#
# All functions are deterministic — they produce no
# wall-clock timestamps.

set -euo pipefail

# Resolve the repo root (the directory containing this
# lib/ folder's parent's parent, i.e. floxenvs/).
sh_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Resolve the directory for an item, given <kind> <name>.
# env  → <name>
# pkg  → .flox/pkgs/<name>
sh_item_dir() {
  local kind="$1" name="$2"
  case "$kind" in
    env) echo "$name" ;;
    pkg) echo ".flox/pkgs/$name" ;;
    *) echo "unknown kind: $kind" >&2; return 2 ;;
  esac
}

# Print a single audit check object as JSON.
# Args: id (string) pass (true|false) weight (int) note (opt)
sh_check_json() {
  local id="$1" pass="$2" weight="$3" note="${4:-}"
  if [ -z "$note" ]; then
    jq -nc \
      --arg id "$id" \
      --argjson pass "$pass" \
      --argjson weight "$weight" \
      '{id:$id, pass:$pass, weight:$weight}'
  else
    jq -nc \
      --arg id "$id" \
      --argjson pass "$pass" \
      --argjson weight "$weight" \
      --arg note "$note" \
      '{id:$id, pass:$pass, weight:$weight, note:$note}'
  fi
}

# Aggregate an array of check JSON objects from stdin
# into a quality section with weighted score.
# stdin: one check JSON per line.
sh_aggregate_quality() {
  jq -s '
    {
      score: (
        if length == 0 then 0
        else
          ([.[] | select(.pass) | .weight] | add // 0)
          * 100 / ([.[].weight] | add // 1)
          | floor
        end
      ),
      checks: .,
    }
  '
}

# Print true if a file exists, false otherwise (string).
sh_exists_json() {
  if [ -e "$1" ]; then echo true; else echo false; fi
}

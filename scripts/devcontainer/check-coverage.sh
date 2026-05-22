#!/usr/bin/env bash
#
# Invariant: every flox environment in the repo must be
# accounted for in the devcontainer setup. Each env must
# fall into exactly one bucket:
#
#   covered     -> .devcontainer/<env>/devcontainer.json exists
#   skip-tag    -> <env>/.devcontainer.toml sets `skip = true`
#   skip-system -> lockfile declares no Linux system support
#
# An env that doesn't fit any bucket is a coverage gap and
# fails the check. Run after `generate-devcontainers` in CI
# (it will also detect generator bugs that swallow envs).
#
# Requires: bash, jq, yj.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/devcontainer/lib.sh disable=SC1091
. "$REPO_ROOT/scripts/devcontainer/lib.sh"

covered=()
skip_tag=()
skip_system=()
uncovered=()

while IFS= read -r lock; do
  env_dir="$(basename \
    "$(dirname "$(dirname "$(dirname "$lock")")")")"
  overlay_toml="$env_dir/.devcontainer.toml"
  overlay_json="$(toml_to_json "$overlay_toml")"

  reason="$(should_skip "$overlay_json" "$lock")"
  out="$REPO_ROOT/.devcontainer/$env_dir/devcontainer.json"

  case "$reason" in
    explicit) skip_tag+=("$env_dir") ;;
    no-linux) skip_system+=("$env_dir") ;;
    "")
      if [ -f "$out" ]; then
        covered+=("$env_dir")
      else
        uncovered+=("$env_dir")
      fi
      ;;
    *)
      echo "ERROR: unknown skip reason '$reason' for $env_dir" >&2
      exit 2
      ;;
  esac
done < <(find . -maxdepth 4 -path '*/.flox/env/manifest.lock' \
  -not -path './.flox/*' \
  -not -path './_worktrees/*' \
  -not -path './.worktrees/*' \
  -not -path '*/remote/*' \
  -not -path '*/.git/*' \
  | sort)

print_list() {
  local label="$1"
  shift
  printf '  %s (%d)\n' "$label" "$#"
  for e in "$@"; do printf '    - %s\n' "$e"; done
}

echo "Devcontainer coverage:"
print_list "covered"     "${covered[@]}"
print_list "skip-tag"    "${skip_tag[@]}"
print_list "skip-system" "${skip_system[@]}"

if [ "${#uncovered[@]}" -gt 0 ]; then
  echo ""
  echo "FAIL: envs without devcontainer.json or explicit skip:"
  for e in "${uncovered[@]}"; do printf '  - %s\n' "$e"; done
  echo ""
  echo "Fix: either run 'just generate-devcontainers' to"
  echo "generate the missing config, or add"
  echo "  skip = true"
  echo "to <env>/.devcontainer.toml if the env intentionally"
  echo "has no devcontainer."
  exit 1
fi

echo ""
echo "OK: all envs accounted for."

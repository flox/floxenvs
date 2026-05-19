#!/usr/bin/env bash
#
# Read file paths on stdin (one per line). Emit each
# distinct item touched, formatted as <kind>:<name>, one
# per line.
#
# Mapping:
#   <X>/...              -> env:<X>      (X has meta.yaml)
#   <X>-demo/...         -> env:<X>
#   .flox/pkgs/<Y>/...   -> pkg:<Y>
#
# Shared-infra paths trigger "emit all items":
#   .gitleaks.toml, .semgrep/**, scripts/lib/**,
#   scripts/run-flox-evals.sh,
#   .github/workflows/website.yml
#   flake.nix or flake.lock (envs only)
#   .flox/env/manifest.toml or manifest.lock (pkgs only)
#
# Lines that don't map to anything are silently dropped.

set -euo pipefail

ROOT="${REPO_ROOT:-$(pwd)}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

emit_all_envs=false
emit_all_pkgs=false
declare -A items=()

while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    .gitleaks.toml|.semgrep/*|\
    scripts/lib/*|scripts/run-flox-evals.sh|\
    .github/workflows/website.yml)
      emit_all_envs=true
      emit_all_pkgs=true
      ;;
    flake.nix|flake.lock)
      emit_all_envs=true
      ;;
    .flox/env/manifest.toml|.flox/env/manifest.lock)
      emit_all_pkgs=true
      ;;
    .flox/pkgs/*/*)
      pkg=$(echo "$line" | cut -d/ -f3)
      items["pkg:$pkg"]=1
      ;;
    .website/*|.github/*|scripts/*|.plans/*|.worktrees/*|.gitignore)
      ;;
    */*)
      top=$(echo "$line" | cut -d/ -f1)
      case "$top" in *-demo) top="${top%-demo}" ;; esac
      [ -f "$ROOT/$top/meta.yaml" ] && items["env:$top"]=1
      ;;
  esac
done

if $emit_all_envs || $emit_all_pkgs; then
  while IFS= read -r item; do
    case "$item" in
      env:*) $emit_all_envs && items["$item"]=1 ;;
      pkg:*) $emit_all_pkgs && items["$item"]=1 ;;
    esac
  done < <( ( cd "$ROOT" && REPO_ROOT="$ROOT" \
              "$SELF_DIR/list-items.sh" ) )
fi

for k in "${!items[@]}"; do
  echo "$k"
done | sort -u

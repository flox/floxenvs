#!/usr/bin/env bash
# Validate <dir>/meta.yaml for an item. Emits a JSON
# quality section (same shape as metrics-defaults) on
# stdout. Returns 2 for an unknown kind.
#
# Usage: lint-meta.sh <kind> <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

KIND="${1:?kind required: env|pkg}"
NAME="${2:?name required}"

case "$KIND" in
  env|pkg) ;;
  *) echo "unknown kind: $KIND" >&2; exit 2 ;;
esac

dir="$NAME"
meta="$ROOT/$dir/meta.yaml"

if [ ! -f "$meta" ]; then
  jq -nc \
    --arg kind "$KIND" --arg name "$NAME" \
    '{ score: 0, checks: [
       {id:"meta-yaml-exists", pass:false, weight:30,
        note:"no meta.yaml"} ] }'
  exit 0
fi

# Check if a scalar field is present and non-empty.
# Returns 0 (true) if field has a non-empty value.
_field_present() {
  local field="$1"
  yq -e \
    "has(\"${field}\") and .${field} != null \
     and (.${field} | length > 0)" \
    "$meta" >/dev/null 2>&1
}

check_field() {
  local field="$1" weight="$2"
  if _field_present "$field"; then
    sh_check_json "meta-yaml-${field}" true "$weight"
  else
    sh_check_json "meta-yaml-${field}" false "$weight" \
      "field '${field}' missing or empty"
  fi
}

required_common=(name title publisher tagline category \
                 tags status license links)
required_env=(install)
required_pkg=(install)

{
  for f in "${required_common[@]}"; do
    check_field "$f" 5
  done

  case "$KIND" in
    env) for f in "${required_env[@]}"; do
           check_field "$f" 5
         done ;;
    pkg) for f in "${required_pkg[@]}"; do
           check_field "$f" 5
         done ;;
  esac

  declared=$(yq -r '.kind // "missing"' "$meta")
  if [ "$declared" = "$KIND" ]; then
    sh_check_json "meta-yaml-kind" true 5
  else
    sh_check_json "meta-yaml-kind" false 5 \
      "kind=${declared}, expected=${KIND}"
  fi

  cat_val=$(yq -r '.category // ""' "$meta")
  if [ "$cat_val" = "ai" ]; then
    if _field_present "ai_role"; then
      sh_check_json "meta-yaml-ai-role" true 5
    else
      sh_check_json "meta-yaml-ai-role" false 5 \
        "category=ai requires ai_role"
    fi
  fi

  if yq -e \
       'has("combines_well_with") and
        .combines_well_with != null and
        (.combines_well_with | length > 0)' \
       "$meta" >/dev/null 2>&1; then
    if yq -e '
      .combines_well_with | all(
        test("^env:") or test("^pkg:")
      )
    ' "$meta" >/dev/null 2>&1; then
      sh_check_json "meta-yaml-cww-prefixed" true 5
    else
      sh_check_json "meta-yaml-cww-prefixed" false 5 \
        "combines_well_with entries must start with env: or pkg:"
    fi
  fi

} | sh_aggregate_quality

#!/usr/bin/env bash
#
# Audit a single Claude Code skill package: build it (if needed),
# locate its skill content, and run the flox-ai audit engine, writing
# audit/skill/<name>/metrics.json.
#
# This script audits SKILLS ONLY. Other item kinds (env, pkg, agent)
# are not handled here.
#
# Usage: run-audit.sh skill <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

KIND="${1:?kind}"
NAME="${2:?name}"

if [ "$KIND" != "skill" ]; then
  echo "run-audit.sh audits skills only (got kind '$KIND')" >&2
  exit 2
fi

out_dir="$ROOT/audit/$KIND/$NAME"
mkdir -p "$out_dir"
out_file="$out_dir/metrics.json"

# The .flox/pkgs/<name> source holds only packaging files — the actual
# skill content (SKILL.md, .claude-plugin) is produced by the build,
# fetched from upstream. Build to materialize it. `flox build` must NOT
# run inside an activated env (it breaks with "attribute 'lib' missing"),
# so CI pre-builds in a separate, non-activated step and this script just
# consumes result-<name>; standalone/local use builds on demand.
built="$ROOT/result-$NAME"
if [ ! -d "$built" ]; then
  ( cd "$ROOT" && flox build "$NAME" ) \
    || { echo "build failed for $NAME" >&2; exit 1; }
fi

# A fragment build emits the same skill under one dir per agent launcher.
# We audit ONE copy, preferring Claude. Probe these bases in this fixed
# order and use the first that exists and holds a content dir — each base
# is checked exactly once. Claude comes first.
content=""
for base in \
  "share/flox/claude" \
  "share/flox/opencode" \
  "share/flox/codex" \
  "share/flox/pi"
do
  abs_base="$built/$base"
  [ -d "$abs_base" ] || continue
  content="$(find "$abs_base" -mindepth 1 -maxdepth 1 -type d | sort | head -1)"
  [ -n "$content" ] && break
done
[ -n "$content" ] || content="$built"

# Runner: flox-ai (the audit engine) from PATH, else a local build.
if command -v flox-ai >/dev/null 2>&1; then
  runner=(flox-ai)
elif [ -x "$ROOT/result-flox-ai/bin/flox-ai" ]; then
  runner=("$ROOT/result-flox-ai/bin/flox-ai")
else
  echo "flox-ai audit runner not found" >&2; exit 1
fi
"${runner[@]}" audit --json --kind "$KIND" "$content" > "$out_file"
echo "wrote $out_file (content: ${content#"$ROOT"/})"

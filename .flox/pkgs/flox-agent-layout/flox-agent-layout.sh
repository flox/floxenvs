#!/usr/bin/env bash
# flox-agent-layout --plugin <name> --root <share/flox dir>
# Emits per-agent views under <root>/<agent>/<plugin> from the canonical
# content in <root>/common/<plugin>. Relative symlinks keep content stored
# once. Run at package build time (read-only at runtime afterward).
set -euo pipefail

plugin=""
root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plugin) plugin="$2"; shift 2 ;;
    --root)   root="$2";   shift 2 ;;
    *) echo "flox-agent-layout: unknown arg $1" >&2; exit 2 ;;
  esac
done
[ -n "$plugin" ] || { echo "flox-agent-layout: --plugin required" >&2; exit 2; }
[ -n "$root" ]   || { echo "flox-agent-layout: --root required" >&2; exit 2; }

common="$root/common/$plugin"
[ -d "$common" ] || { echo "flox-agent-layout: $common not found" >&2; exit 2; }

# claude: a Claude Code plugin (manifest + skills/ + agents/).
cdir="$root/claude/$plugin"
mkdir -p "$cdir/.claude-plugin"
printf '{"name":"%s","description":"Flox-managed: %s"}\n' "$plugin" "$plugin" \
  > "$cdir/.claude-plugin/plugin.json"
if [ -d "$common/skills" ]; then
  mkdir -p "$cdir/skills"
  for s in "$common/skills"/*/; do
    [ -e "$s" ] || continue
    name="$(basename "$s")"
    ln -sfn "../../../common/$plugin/skills/$name" "$cdir/skills/$name"
  done
fi
if [ -d "$common/agents" ]; then
  mkdir -p "$cdir/agents"
  for a in "$common/agents"/*.md; do
    [ -e "$a" ] || continue
    name="$(basename "$a")"
    ln -sfn "../../../common/$plugin/agents/$name" "$cdir/agents/$name"
  done
fi

# codex + pi: bare skill roots — <plugin>/<name> -> common skill dir.
for agent in codex pi; do
  adir="$root/$agent/$plugin"
  if [ -d "$common/skills" ]; then
    mkdir -p "$adir"
    for s in "$common/skills"/*/; do
      [ -e "$s" ] || continue
      name="$(basename "$s")"
      ln -sfn "../../common/$plugin/skills/$name" "$adir/$name"
    done
  fi
done

# opencode: skills/<name> under the plugin folder (scanned by **/SKILL.md).
odir="$root/opencode/$plugin"
if [ -d "$common/skills" ]; then
  mkdir -p "$odir/skills"
  for s in "$common/skills"/*/; do
    [ -e "$s" ] || continue
    name="$(basename "$s")"
    ln -sfn "../../../common/$plugin/skills/$name" "$odir/skills/$name"
  done
fi

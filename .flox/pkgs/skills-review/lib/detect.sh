#!/usr/bin/env bash
# Decide whether a path is a skill or an agent.

detect_kind() {
  local path="$1" fm
  if [ -d "$path" ] && [ -f "$path/SKILL.md" ]; then echo skill; return; fi
  if [ -f "$path" ]; then
    # Agent if frontmatter carries agent-only keys.
    fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$path")
    if printf '%s\n' "$fm" | grep -qE '^(model|tools|disallowedTools|permissionMode|color|maxTurns):'; then
      echo agent; return
    fi
    case "$path" in */agents/*) echo agent; return ;; esac
  fi
  echo skill
}

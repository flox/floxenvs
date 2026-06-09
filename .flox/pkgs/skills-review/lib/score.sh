#!/usr/bin/env bash
# Scoring helpers for skills-review. Pure functions, jq/awk-backed.

# clamp(100 - 25*errors - 5*warnings, 0, 100)
normalize_errwarn() {
  local err="$1" warn="$2" s
  s=$(( 100 - 25 * err - 5 * warn ))
  [ "$s" -lt 0 ] && s=0
  [ "$s" -gt 100 ] && s=100
  echo "$s"
}

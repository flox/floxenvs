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

# Weighted mean of 3 (weight%,score) pairs, rounded.
ensemble3() {
  awk -v w1="$1" -v s1="$2" -v w2="$3" -v s2="$4" -v w3="$5" -v s3="$6" \
    'BEGIN { printf "%.0f\n", (w1*s1 + w2*s2 + w3*s3) / 100 }'
}

# Plan-B weighted average: quality35 reliability35 security20 impact10.
fuse() {
  awk -v q="$1" -v r="$2" -v s="$3" -v i="$4" \
    'BEGIN { printf "%.0f\n", 0.35*q + 0.35*r + 0.20*s + 0.10*i }'
}

# Cap a fused score by the highest security severity present.
apply_cap() {
  local score="$1" sev="$2" cap=100
  case "$sev" in
    CRITICAL) cap=50 ;;
    HIGH)     cap=75 ;;
  esac
  [ "$score" -gt "$cap" ] && score="$cap"
  echo "$score"
}

# Status pill from a 0-100 score.
pill() {
  local s="$1"
  if [ "$s" -ge 80 ]; then echo stable
  elif [ "$s" -ge 60 ]; then echo warn
  else echo risk; fi
}

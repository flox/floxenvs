#!/usr/bin/env bats

load test_helper/common

# overall_of <path> [extra audit args...]
# Echoes the integer overall score from `audit --json`.
overall_of() {
  review-skills audit --json "$@" | jq -r '.overall'
}

@test "good skill audits as a skill with a numeric overall and a healthy status" {
  good="$(fixture good-skill)"
  run review-skills audit "$good"
  assert_success
  # "<kind> <name>: <overall> (<status>)"
  assert_output --regexp '^skill good-skill: [0-9]+ \((stable|warn|risk)\)$'
  refute_output --partial 'risk'
}

@test "good skill scores strictly higher than the bad skill" {
  good="$(fixture good-skill)"
  bad="$(fixture bad-skill)"
  good_score="$(overall_of "$good")"
  bad_score="$(overall_of "$bad")"
  echo "good=$good_score bad=$bad_score"
  [ "$good_score" -gt "$bad_score" ]
}

@test "audit --json parses and carries overall, quality and status" {
  good="$(fixture good-skill)"
  run review-skills audit --json "$good"
  assert_success
  echo "$output" | jq -e '.overall | numbers' >/dev/null
  echo "$output" | jq -e '.status | strings' >/dev/null
  echo "$output" | jq -e '.quality.score | numbers' >/dev/null
  echo "$output" | jq -e '.quality.checks | arrays' >/dev/null
}

@test "audit --findings yields a findings array" {
  good="$(fixture good-skill)"
  run review-skills audit --json --findings "$good"
  assert_success
  # findings is an array (possibly empty, but present and well-formed)
  echo "$output" | jq -e '.findings | type == "array"' >/dev/null
}

@test "audit --threshold 100 exits 1 (overall below 100)" {
  good="$(fixture good-skill)"
  run review-skills audit --threshold 100 "$good"
  assert_failure
}

@test "audit --threshold 1 exits 0" {
  good="$(fixture good-skill)"
  run review-skills audit --threshold 1 "$good"
  assert_success
}

@test "agent file is auto-detected as kind agent and is stable/warn" {
  agent="$(fixture good-agent.md)"
  run review-skills audit "$agent"
  assert_success
  # the identity name for an agent file is its basename (with extension)
  assert_output --regexp '^agent good-agent\.md: [0-9]+ \((stable|warn|risk)\)$'
  refute_output --partial 'risk'
}

@test "agent audit --json reports identity.kind agent" {
  agent="$(fixture good-agent.md)"
  run review-skills audit --json "$agent"
  assert_success
  assert_equal "$(echo "$output" | jq -r '.identity.kind')" "agent"
}

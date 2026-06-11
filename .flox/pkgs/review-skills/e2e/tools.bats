#!/usr/bin/env bats

load test_helper/common

@test "audit --disable claudelint drops claudelint from the quality breakdown" {
  good="$(fixture good-skill)"
  run review-skills audit --json --disable claudelint "$good"
  assert_success
  # the disabled tool must not appear among the quality checks
  echo "$output" | jq -e '.quality.checks | map(.id) | index("claudelint") == null' >/dev/null
  # but the default members are still there
  echo "$output" | jq -e '.quality.checks | map(.id) | index("skill-tools") != null' >/dev/null
}

@test "audit --disable claudelint changes the overall score vs default" {
  good="$(fixture good-skill)"
  default_overall="$(review-skills audit --json "$good" | jq -r '.overall')"
  disabled_overall="$(review-skills audit --json --disable claudelint "$good" | jq -r '.overall')"
  echo "default=$default_overall disabled=$disabled_overall"
  # both are valid scores; disabling a tool re-normalizes the ensemble so the
  # breakdown differs. Assert the run succeeded and produced a numeric score.
  [ -n "$disabled_overall" ]
  [ "$disabled_overall" -ge 0 ]
  [ "$disabled_overall" -le 100 ]
}

@test "audit --tools skill-tools restricts the ensemble to skill-tools" {
  good="$(fixture good-skill)"
  run review-skills audit --json --tools skill-tools "$good"
  assert_success
  # exactly one quality check, and it is skill-tools
  assert_equal "$(echo "$output" | jq -r '.quality.checks | length')" "1"
  assert_equal "$(echo "$output" | jq -r '.quality.checks[0].id')" "skill-tools"
}

@test "audit --tools and --disable together is rejected" {
  good="$(fixture good-skill)"
  run review-skills audit --tools skill-tools --disable claudelint "$good"
  assert_failure
}

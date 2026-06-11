#!/usr/bin/env bats

load test_helper/common

@test "review prints a quality score one-liner" {
  good="$(fixture good-skill)"
  run review-skills review "$good"
  assert_success
  assert_output --regexp '^skill good-skill: quality [0-9]+$'
}

@test "review --json carries a numeric quality score" {
  good="$(fixture good-skill)"
  run review-skills review --json "$good"
  assert_success
  echo "$output" | jq -e '.score | numbers' >/dev/null
  echo "$output" | jq -e '.checks | arrays' >/dev/null
}

@test "review --threshold above the score exits 1" {
  good="$(fixture good-skill)"
  run review-skills review --threshold 100 "$good"
  assert_failure
}

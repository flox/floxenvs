#!/usr/bin/env bats

load test_helper/common

@test "lint passes on a clean skill (exit 0)" {
  good="$(fixture good-skill)"
  run review-skills lint "$good"
  assert_success
  assert_output --partial "lint: OK"
}

@test "lint fails on a malformed skill (exit 1)" {
  bad="$(fixture bad-skill)"
  run review-skills lint "$bad"
  assert_failure
  assert_output --partial "FAILED"
}

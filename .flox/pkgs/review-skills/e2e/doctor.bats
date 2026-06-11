#!/usr/bin/env bats

load test_helper/common

@test "doctor prints the availability table header" {
  run review-skills doctor
  assert_output --partial "TOOL"
  assert_output --partial "STATE"
  assert_output --partial "VERSION"
  assert_output --partial "SMOKE"
}

@test "doctor lists every orchestrated tool" {
  run review-skills doctor
  assert_output --partial "skill-tools"
  assert_output --partial "skill-validator"
  assert_output --partial "claudelint"
  assert_output --partial "cclint"
  assert_output --partial "agnix"
  assert_output --partial "skillcheck"
}

@test "doctor shows the resolved skill and agent ensembles" {
  run review-skills doctor
  assert_output --partial "skill audit → uses:"
  assert_output --partial "agent audit → uses:"
}

@test "doctor succeeds when every default tool is on PATH" {
  run review-skills doctor
  assert_success
}

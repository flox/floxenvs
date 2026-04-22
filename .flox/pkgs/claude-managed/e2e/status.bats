#!/usr/bin/env bats

load test_helper/common

@test "status shows config dir path" {
  run_cm status
  assert_success
  assert_output --partial 'config:'
}

@test "status shows not activated when CLAUDE_MANAGED unset" {
  if [[ "$TEST_MODE" == "flox" ]]; then
    skip "CLAUDE_MANAGED may be set in flox mode"
  fi
  run_cm status
  assert_success
  assert_output --partial 'not activated'
}

@test "status shows Rules section" {
  run_cm status
  assert_success
  assert_output --partial 'Rules'
}

@test "status shows Skills section" {
  run_cm status
  assert_success
  assert_output --partial 'Skills'
}

@test "status shows Agents section" {
  run_cm status
  assert_success
  assert_output --partial 'Agents'
}

@test "status shows validation issues inline" {
  run_cm status
  assert_success
  assert_output --partial 'bad-frontmatter'
}

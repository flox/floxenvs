#!/usr/bin/env bats

load test_helper/common

@test "setup-profile contains trap registration" {
  run_cm setup-profile
  assert_success
  assert_output --partial 'trap _claude_managed_cleanup EXIT'
}

@test "setup-profile contains cleanup function" {
  run_cm setup-profile
  assert_success
  assert_output --partial '_claude_managed_cleanup()'
}

@test "setup-profile contains clean_symlinks helper" {
  run_cm setup-profile
  assert_success
  assert_output --partial '_claude_managed_clean_symlinks()'
}

@test "setup-profile does NOT export CLAUDE_CONFIG_DIR" {
  run_cm setup-profile
  assert_success
  refute_output --partial 'export CLAUDE_CONFIG_DIR='
}

@test "setup-profile does NOT export CLAUDE_MANAGED" {
  run_cm setup-profile
  assert_success
  refute_output --partial 'export CLAUDE_MANAGED='
}

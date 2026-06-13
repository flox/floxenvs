#!/usr/bin/env bats

load test_helper/common

@test "setup-profile contains trap registration" {
  run_cm setup-profile
  assert_success
  assert_output --partial 'trap _flox_ai_cleanup EXIT'
}

@test "setup-profile contains cleanup function" {
  run_cm setup-profile
  assert_success
  assert_output --partial '_flox_ai_cleanup()'
}

@test "setup-profile re-exports PATH for interactive shells" {
  run_cm setup-profile
  assert_success
  assert_output --partial 'export PATH="$CLAUDE_CONFIG_DIR/bin:$PATH"'
}

@test "setup-profile does NOT export CLAUDE_CONFIG_DIR" {
  run_cm setup-profile
  assert_success
  refute_output --partial 'export CLAUDE_CONFIG_DIR='
}

@test "setup-profile does NOT export FLOX_AI" {
  run_cm setup-profile
  assert_success
  refute_output --partial 'export FLOX_AI='
}

@test "setup-profile-bash matches setup-profile" {
  run_cm setup-profile-bash
  assert_success
  assert_output --partial 'trap _flox_ai_cleanup EXIT'
  assert_output --partial 'export PATH="$CLAUDE_CONFIG_DIR/bin:$PATH"'
}

@test "setup-profile-zsh matches setup-profile" {
  run_cm setup-profile-zsh
  assert_success
  assert_output --partial 'trap _flox_ai_cleanup EXIT'
  assert_output --partial 'export PATH="$CLAUDE_CONFIG_DIR/bin:$PATH"'
}

@test "setup-profile-fish uses fish syntax" {
  run_cm setup-profile-fish
  assert_success
  assert_output --partial 'set -gx PATH "$CLAUDE_CONFIG_DIR/bin" $PATH'
  assert_output --partial '--on-event fish_exit'
  refute_output --partial 'trap _flox_ai_cleanup EXIT'
}

#!/usr/bin/env bats

load test_helper/common

@test "setup-hook exports CLAUDE_CONFIG_DIR" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'export CLAUDE_CONFIG_DIR='
}

@test "setup-hook exports CLAUDE_MANAGED=1" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'export CLAUDE_MANAGED=1'
}

@test "setup-hook exports CLAUDE_CODE_DISABLE_AUTO_MEMORY=1" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1'
}

@test "setup-hook creates symlinks for valid rule" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'ln -sfn'
  assert_output --partial 'rules/valid.md'
}

@test "setup-hook creates symlinks for valid skill" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'ln -sfn'
  assert_output --partial 'skills/my-skill'
}

@test "setup-hook creates symlinks for valid agent" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'ln -sfn'
  assert_output --partial 'agents/valid-agent.md'
}

@test "setup-hook contains keychain bridge on Darwin" {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    skip "keychain bridge is macOS-only"
  fi
  run_cm setup-hook
  assert_success
  assert_output --partial 'security add-generic-password'
}

@test "setup-hook warns on bad frontmatter" {
  run_cm_split setup-hook
  [[ "$CM_STDERR" == *"WARN:"* ]]
  [[ "$CM_STDERR" == *"unknown frontmatter key"* ]]
}

@test "setup-hook warns on forbidden agent key" {
  run_cm_split setup-hook
  [[ "$CM_STDERR" == *"WARN:"* ]]
  [[ "$CM_STDERR" == *"forbidden frontmatter key"* ]]
}

@test "setup-hook warns on invalid skill name" {
  run_cm_split setup-hook
  [[ "$CM_STDERR" == *"WARN:"* ]]
  [[ "$CM_STDERR" == *"must be kebab-case"* ]]
}

@test "setup-hook warns on invalid effort" {
  run_cm_split setup-hook
  [[ "$CM_STDERR" == *"WARN:"* ]]
  [[ "$CM_STDERR" == *"must be low|medium|high|max"* ]]
}

@test "setup-hook without --dir or FLOX_ENV fails" {
  if [[ "$TEST_MODE" == "flox" ]]; then
    skip "FLOX_ENV is always set in flox mode"
  fi
  unset FLOX_ENV
  run claude-managed setup-hook
  assert_failure
  assert_output --partial "ERROR:"
  assert_output --partial "--dir is required"
}

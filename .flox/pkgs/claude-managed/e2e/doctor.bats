#!/usr/bin/env bats

load test_helper/common

@test "doctor reports valid rule with checkmark" {
  run_cm doctor
  assert_output --regexp '✓.*valid'
}

@test "doctor reports bad frontmatter with X" {
  run_cm doctor
  assert_output --regexp '✗.*bad-frontmatter'
  assert_output --partial 'unknown frontmatter key'
}

@test "doctor reports forbidden agent key" {
  run_cm doctor
  assert_output --regexp '✗.*forbidden-hooks'
  assert_output --partial 'forbidden frontmatter key'
}

@test "doctor reports invalid skill name" {
  run_cm doctor
  assert_output --regexp '✗.*Bad-Name'
  assert_output --partial 'must be kebab-case'
}

@test "doctor reports invalid effort" {
  run_cm doctor
  assert_output --regexp '✗.*bad-effort'
  assert_output --partial 'must be low|medium|high|max'
}

@test "doctor exits 1 when issues found" {
  run_cm doctor
  assert_failure
}

@test "doctor exits 0 when all valid" {
  local dir="$BATS_TEST_TMPDIR/clean"
  mkdir -p "$dir/rules"
  cat > "$dir/rules/good.md" <<'EOF'
# Good rule

This rule is clean.
EOF
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_success
  assert_output --partial 'All valid'
}

@test "doctor shows 'No rules found.' for empty dir" {
  local dir="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$dir"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_success
  assert_output --partial 'No rules found'
  assert_output --partial 'No skills found'
  assert_output --partial 'No agents found'
}

@test "doctor shows sections: Rules, Skills, Agents" {
  run_cm doctor
  assert_output --partial 'Rules'
  assert_output --partial 'Skills'
  assert_output --partial 'Agents'
}

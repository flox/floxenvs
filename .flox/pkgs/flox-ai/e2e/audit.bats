#!/usr/bin/env bats

load test_helper/common

# audit scores a skill/agent in-process via the absorbed review engine. These
# tests run under REVIEW_SKILLS_DRY_RUN so they need no external quality tools
# on PATH and produce deterministic stub scores.

setup() {
  export REVIEW_SKILLS_DRY_RUN=1
}

skill_dir() {
  local d
  d="$(setup_fixtures)"
  echo "$d/skills/my-skill"
}

@test "audit prints a human summary with dimension scores" {
  run flox-ai audit "$(skill_dir)" --kind skill
  assert_success
  assert_output --partial 'overall'
  assert_output --partial 'quality'
}

@test "audit --json emits a machine-readable document" {
  run flox-ai audit "$(skill_dir)" --kind skill --json
  assert_success
  assert_output --partial '"overall"'
  assert_output --partial '"quality"'
}

@test "audit --report includes raw per-tool sections" {
  run flox-ai audit "$(skill_dir)" --kind skill --report
  assert_success
  assert_output --partial '==='
}

@test "audit --threshold above the score exits nonzero" {
  run flox-ai audit "$(skill_dir)" --kind skill --threshold 200
  assert_failure
}

@test "audit honors flags placed after the path" {
  run flox-ai audit "$(skill_dir)" --kind skill --threshold 200 --json
  assert_failure
  assert_output --partial '"overall"'
}

@test "audit with no path errors with usage" {
  run flox-ai audit
  assert_failure
  assert_output --partial 'usage: flox-ai audit'
}

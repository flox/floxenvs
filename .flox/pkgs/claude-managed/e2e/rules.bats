#!/usr/bin/env bats

load test_helper/common

@test "rules add creates symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  assert_success
  [[ -L "$config_dir/rules/valid.md" ]]
}

@test "rules add creates relative symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  local target
  target="$(readlink "$config_dir/rules/valid.md")"
  [[ "$target" != /* ]]
}

@test "rules add is idempotent" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  run claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  assert_success
}

@test "rules remove deletes symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  run claude-managed --config-dir "$config_dir" \
    rules remove valid.md
  assert_success
  [[ ! -L "$config_dir/rules/valid.md" ]]
}

@test "rules list shows installed rules" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  run claude-managed --config-dir "$config_dir" \
    rules list
  assert_success
  assert_output --partial 'valid.md'
}

@test "rules list shows empty message" {
  local config_dir
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    rules list
  assert_success
  assert_output --partial 'No rules found'
}

@test "rules clean removes managed symlinks" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    rules add "$dir/rules/valid.md"
  run claude-managed --dir "$dir" \
    --config-dir "$config_dir" rules clean
  assert_success
  [[ ! -L "$config_dir/rules/valid.md" ]]
}

@test "rules clean preserves user symlinks" {
  local config_dir user_file
  config_dir="$(setup_config_dir)"
  user_file="$BATS_TEST_TMPDIR/user-rule.md"
  echo "# User rule" > "$user_file"
  mkdir -p "$config_dir/rules"
  ln -sfn "$user_file" "$config_dir/rules/user-rule.md"
  run claude-managed --dir /nonexistent \
    --config-dir "$config_dir" rules clean
  [[ -L "$config_dir/rules/user-rule.md" ]]
}

#!/usr/bin/env bats

load test_helper/common

@test "agents add creates symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    agents add "$dir/agents/valid-agent.md"
  assert_success
  [[ -L "$config_dir/agents/valid-agent.md" ]]
}

@test "agents add creates relative symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    agents add "$dir/agents/valid-agent.md"
  local target
  target="$(readlink "$config_dir/agents/valid-agent.md")"
  [[ "$target" != /* ]]
}

@test "agents remove deletes symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    agents add "$dir/agents/valid-agent.md"
  run claude-managed --config-dir "$config_dir" \
    agents remove valid-agent.md
  assert_success
  [[ ! -L "$config_dir/agents/valid-agent.md" ]]
}

@test "agents list shows installed agents" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    agents add "$dir/agents/valid-agent.md"
  run claude-managed --config-dir "$config_dir" \
    agents list
  assert_success
  assert_output --partial 'valid-agent.md'
}

@test "agents list shows empty message" {
  local config_dir
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    agents list
  assert_success
  assert_output --partial 'No agents found'
}

@test "agents clean removes managed symlinks" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    agents add "$dir/agents/valid-agent.md"
  run claude-managed --dir "$dir" \
    --config-dir "$config_dir" agents clean
  assert_success
  [[ ! -L "$config_dir/agents/valid-agent.md" ]]
}

@test "agents clean preserves user symlinks" {
  local config_dir user_file
  config_dir="$(setup_config_dir)"
  user_file="$BATS_TEST_TMPDIR/user-agent.md"
  echo "# User agent" > "$user_file"
  mkdir -p "$config_dir/agents"
  ln -sfn "$user_file" "$config_dir/agents/user-agent.md"
  run claude-managed --dir /nonexistent \
    --config-dir "$config_dir" agents clean
  [[ -L "$config_dir/agents/user-agent.md" ]]
}

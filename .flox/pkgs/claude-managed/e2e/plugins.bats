#!/usr/bin/env bats

load test_helper/common

@test "plugins add creates symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  assert_success
  [[ -L "$config_dir/plugins/valid-plugin" ]]
}

@test "plugins add merges installed_plugins.json" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  [[ -f "$config_dir/plugins/installed_plugins.json" ]]
  run grep "valid-plugin@flox" \
    "$config_dir/plugins/installed_plugins.json"
  assert_success
}

@test "plugins add merges known_marketplaces.json" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  [[ -f "$config_dir/plugins/known_marketplaces.json" ]]
  run grep "flox" \
    "$config_dir/plugins/known_marketplaces.json"
  assert_success
}

@test "plugins remove deletes symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  run claude-managed --config-dir "$config_dir" \
    plugins remove valid-plugin
  assert_success
  [[ ! -L "$config_dir/plugins/valid-plugin" ]]
}

@test "plugins remove regenerates JSON without removed plugin" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  claude-managed --config-dir "$config_dir" \
    plugins remove valid-plugin
  [[ ! -f "$config_dir/plugins/installed_plugins.json" ]]
}

@test "plugins list shows installed plugins" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  run claude-managed --config-dir "$config_dir" \
    plugins list
  assert_success
  assert_output --partial 'valid-plugin'
}

@test "plugins list shows empty message" {
  local config_dir
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    plugins list
  assert_success
  assert_output --partial 'No plugins found'
}

@test "plugins clean removes managed symlinks" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  run claude-managed --dir "$dir" \
    --config-dir "$config_dir" plugins clean
  assert_success
  [[ ! -L "$config_dir/plugins/valid-plugin" ]]
}

@test "plugins clean preserves user plugins" {
  local config_dir user_dir
  config_dir="$(setup_config_dir)"
  user_dir="$BATS_TEST_TMPDIR/user-plugin"
  mkdir -p "$user_dir" "$config_dir/plugins"
  ln -sfn "$user_dir" "$config_dir/plugins/user-plugin"
  run claude-managed --dir /nonexistent \
    --config-dir "$config_dir" plugins clean
  [[ -L "$config_dir/plugins/user-plugin" ]]
}

@test "plugins add is idempotent" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  claude-managed --config-dir "$config_dir" \
    plugins add "$dir/plugins/valid-plugin"
  local count
  count="$(grep -c 'valid-plugin@flox' \
    "$config_dir/plugins/installed_plugins.json")"
  [[ "$count" -eq 1 ]]
}

@test "doctor validates plugins" {
  run_cm doctor
  assert_output --partial 'Plugins'
  assert_output --partial 'bad-plugin'
  assert_output --partial 'no recognized components'
}

@test "setup-hook emits plugins clean and add" {
  run_cm setup-hook
  assert_success
  assert_output --partial 'plugins clean'
  assert_output --partial 'plugins add'
  assert_output --partial 'valid-plugin'
}

#!/usr/bin/env bats

load test_helper/common

@test "skills add creates symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    skills add "$dir/skills/my-skill"
  assert_success
  [[ -L "$config_dir/skills/my-skill" ]]
}

@test "skills add creates relative symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    skills add "$dir/skills/my-skill"
  local target
  target="$(readlink "$config_dir/skills/my-skill")"
  [[ "$target" != /* ]]
}

@test "skills remove deletes symlink" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    skills add "$dir/skills/my-skill"
  run claude-managed --config-dir "$config_dir" \
    skills remove my-skill
  assert_success
  [[ ! -L "$config_dir/skills/my-skill" ]]
}

@test "skills list shows installed skills" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    skills add "$dir/skills/my-skill"
  run claude-managed --config-dir "$config_dir" \
    skills list
  assert_success
  assert_output --partial 'my-skill'
}

@test "skills list shows empty message" {
  local config_dir
  config_dir="$(setup_config_dir)"
  run claude-managed --config-dir "$config_dir" \
    skills list
  assert_success
  assert_output --partial 'No skills found'
}

@test "skills clean removes managed symlinks" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  claude-managed --config-dir "$config_dir" \
    skills add "$dir/skills/my-skill"
  run claude-managed --dir "$dir" \
    --config-dir "$config_dir" skills clean
  assert_success
  [[ ! -L "$config_dir/skills/my-skill" ]]
}

@test "skills clean preserves user symlinks" {
  local config_dir user_dir
  config_dir="$(setup_config_dir)"
  user_dir="$BATS_TEST_TMPDIR/user-skill"
  mkdir -p "$user_dir"
  echo "# SKILL" > "$user_dir/SKILL.md"
  mkdir -p "$config_dir/skills"
  ln -sfn "$user_dir" "$config_dir/skills/user-skill"
  run claude-managed --dir /nonexistent \
    --config-dir "$config_dir" skills clean
  [[ -L "$config_dir/skills/user-skill" ]]
}

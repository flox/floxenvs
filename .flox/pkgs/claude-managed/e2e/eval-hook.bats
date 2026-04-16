#!/usr/bin/env bats

load test_helper/common

setup() {
  CM_DIR="$(setup_fixtures)"
  CM_CONFIG_DIR="$(setup_config_dir)"
  export CM_DIR CM_CONFIG_DIR
  # Emitted shell uses $FLOX_ENV for symlink targets —
  # point it at the fixtures grandparent so paths resolve.
  export FLOX_ENV="$(dirname "$(dirname "$CM_DIR")")"
}

_get_hook_output() {
  claude-managed --dir "$CM_DIR" \
    --config-dir "$CM_CONFIG_DIR" setup-hook 2>/dev/null
}

@test "eval setup-hook succeeds" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
}

@test "eval setup-hook sets CLAUDE_CONFIG_DIR" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ -n "$CLAUDE_CONFIG_DIR" ]]
}

@test "eval setup-hook sets CLAUDE_MANAGED=1" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ "$CLAUDE_MANAGED" == "1" ]]
}

@test "eval setup-hook sets CLAUDE_CODE_DISABLE_AUTO_MEMORY=1" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ "$CLAUDE_CODE_DISABLE_AUTO_MEMORY" == "1" ]]
}

@test "eval setup-hook creates rule symlinks" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ -L "$CLAUDE_CONFIG_DIR/rules/valid.md" ]]
}

@test "eval setup-hook creates skill symlinks" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ -L "$CLAUDE_CONFIG_DIR/skills/my-skill" ]]
}

@test "eval setup-hook creates agent symlinks" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ -L "$CLAUDE_CONFIG_DIR/agents/valid-agent.md" ]]
}

@test "eval setup-hook symlink targets exist" {
  local code
  code="$(_get_hook_output)"
  eval "$code"
  [[ -e "$CLAUDE_CONFIG_DIR/rules/valid.md" ]]
}

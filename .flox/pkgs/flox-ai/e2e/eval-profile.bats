#!/usr/bin/env bats

load test_helper/common

setup() {
  CM_DIR="$(setup_fixtures)"
  CM_CONFIG_DIR="$(setup_config_dir)"
  export CM_DIR CM_CONFIG_DIR
  # Emitted shell uses $FLOX_ENV for symlink targets
  export FLOX_ENV="$(dirname "$(dirname "$CM_DIR")")"
  # eval hook first to set up env vars and symlinks
  eval "$(flox-ai --dir "$CM_DIR" \
    --config-dir "$CM_CONFIG_DIR" setup-hook 2>/dev/null)"
}

_get_profile_output() {
  flox-ai --dir "$CM_DIR" \
    --config-dir "$CM_CONFIG_DIR" setup-profile 2>/dev/null
}

@test "eval setup-profile succeeds" {
  local code
  code="$(_get_profile_output)"
  eval "$code"
}

@test "eval setup-profile defines cleanup function" {
  local code
  code="$(_get_profile_output)"
  eval "$code"
  declare -f _flox_ai_cleanup >/dev/null
}


@test "cleanup removes managed symlinks" {
  local code
  code="$(_get_profile_output)"
  eval "$code"
  [[ -L "$CLAUDE_CONFIG_DIR/rules/valid.md" ]]
  _flox_ai_cleanup
  [[ ! -L "$CLAUDE_CONFIG_DIR/rules/valid.md" ]]
}

@test "cleanup does not remove non-managed files" {
  local code
  code="$(_get_profile_output)"
  eval "$code"
  echo "user content" > "$CLAUDE_CONFIG_DIR/rules/user-rule.md"
  _flox_ai_cleanup
  [[ -f "$CLAUDE_CONFIG_DIR/rules/user-rule.md" ]]
}

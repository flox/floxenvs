#!/usr/bin/env bats

load test_helper/common

# launch execs the agent binary (syscall.Exec), replacing the flox-ai
# process. To observe what it would have run, we put a fake agent binary
# first on PATH that records its argv and a few env vars to files, then
# exits 0. flox-ai inherits our PATH (so it resolves the fake) and passes
# our env through to the child (so REC_ARGV / REC_ENV reach the fake).

# make_fake_agent <name> — create an executable recorder named <name> in a
# dedicated bin dir, prepend that dir to PATH, and export REC_ARGV/REC_ENV.
make_fake_agent() {
  local name="$1"
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  export REC_ARGV="$BATS_TEST_TMPDIR/argv.txt"
  export REC_ENV="$BATS_TEST_TMPDIR/env.txt"
  cat > "$bindir/$name" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$REC_ARGV"
{
  echo "FLOX_AI=$FLOX_AI"
  echo "FLOX_AI_DIR=$FLOX_AI_DIR"
  echo "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
  echo "XDG_DATA_HOME=$XDG_DATA_HOME"
  echo "CODEX_FLOX_SKILL_ROOTS=$CODEX_FLOX_SKILL_ROOTS"
  echo "CODEX_FLOX_INSTRUCTIONS_FILE=$CODEX_FLOX_INSTRUCTIONS_FILE"
} > "$REC_ENV"
exit 0
EOF
  chmod +x "$bindir/$name"
  export PATH="$bindir:$PATH"
}

# ---- claude agent --------------------------------------------------------

@test "launch claude execs claude with injected fragments and passthrough" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  make_fake_agent claude

  run flox-ai --dir "$dir" --config-dir "$config_dir" \
    launch claude -- --model opus
  assert_success

  # injected fragments from the fixture share dir
  grep -qx -- '--plugin-dir' "$REC_ARGV"
  grep -qx -- '--append-system-prompt-file' "$REC_ARGV"
  # passthrough reaches claude
  grep -qx -- '--model' "$REC_ARGV"
  grep -qx -- 'opus' "$REC_ARGV"
  # managed-mode marker exported to the child
  grep -qx 'FLOX_AI=1' "$REC_ENV"
}

@test "launch claude strips the -- delimiter from passthrough" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  make_fake_agent claude

  run flox-ai --dir "$dir" --config-dir "$config_dir" \
    launch claude -- --resume
  assert_success

  # the deck/passthrough delimiter must not reach the agent, or claude
  # would parse --resume as a positional arg
  grep -qx -- '--resume' "$REC_ARGV"
  run grep -cx -- '--' "$REC_ARGV"
  assert_output '0'
}

# ---- agent-deck agent ----------------------------------------------------

@test "launch agent-deck seeds config and execs with isolated env" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  make_fake_agent agent-deck

  run flox-ai --dir "$dir" --config-dir "$config_dir" \
    launch agent-deck -- status
  assert_success

  # config seeded under the per-env deck home
  local cfg="$config_dir/agents/agent-deck/config.toml"
  [[ -f "$cfg" ]]
  grep -q "command = 'flox-ai launch claude --'" "$cfg"
  grep -q '\[tmux\]' "$cfg"
  grep -q "socket_name = 'flox-ai-" "$cfg"

  # isolated env: config + data home co-located, FLOX_AI_DIR pinned
  grep -qx "XDG_CONFIG_HOME=$config_dir/agents" "$REC_ENV"
  grep -qx "XDG_DATA_HOME=$config_dir/agents" "$REC_ENV"
  grep -qx "FLOX_AI_DIR=$config_dir" "$REC_ENV"
  grep -qx 'FLOX_AI=1' "$REC_ENV"

  # passthrough reaches agent-deck without the -- delimiter
  run cat "$REC_ARGV"
  assert_output 'status'
}

@test "launch agent-deck derives a stable per-config-dir socket" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  make_fake_agent agent-deck
  local cfg="$config_dir/agents/agent-deck/config.toml"

  flox-ai --dir "$dir" --config-dir "$config_dir" launch agent-deck
  local first
  first="$(grep socket_name "$cfg")"

  flox-ai --dir "$dir" --config-dir "$config_dir" launch agent-deck
  local second
  second="$(grep socket_name "$cfg")"

  [[ "$first" == "$second" ]]
  [[ -n "$first" ]]
}

# ---- codex agent ---------------------------------------------------------

@test "launch codex execs codex with fragments injected via env vars" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  make_fake_agent codex

  run flox-ai --dir "$dir" --config-dir "$config_dir" \
    launch codex -- exec "hello"
  assert_success

  # Codex takes no --plugin-dir / --append-system-prompt-file flags: the
  # fragments are injected through the patch env vars, pointing at staged
  # copies under the per-env codex launch dir.
  grep -qx "CODEX_FLOX_SKILL_ROOTS=$config_dir/codex/skills" "$REC_ENV"
  grep -qx "CODEX_FLOX_INSTRUCTIONS_FILE=$config_dir/codex/rules.md" "$REC_ENV"
  grep -qx 'FLOX_AI=1' "$REC_ENV"

  # the staged skill root and rules file exist on disk
  [[ -d "$config_dir/codex/skills" ]]
  [[ -f "$config_dir/codex/rules.md" ]]

  # passthrough reaches codex without the -- delimiter
  grep -qx -- 'exec' "$REC_ARGV"
  grep -qx -- 'hello' "$REC_ARGV"
  run grep -cx -- '--' "$REC_ARGV"
  assert_output '0'
}

# ---- errors --------------------------------------------------------------

@test "launch rejects an unknown agent" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  run flox-ai --dir "$dir" --config-dir "$config_dir" launch bogus
  assert_failure
  assert_output --partial 'unknown agent'
}

@test "launch with no agent prints usage" {
  run flox-ai launch
  assert_failure
  assert_output --partial 'usage: flox-ai launch'
}

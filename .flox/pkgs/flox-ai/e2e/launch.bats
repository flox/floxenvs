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
  echo "AGENT_DECK_HOME=$AGENT_DECK_HOME"
  echo "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
  echo "XDG_DATA_HOME=$XDG_DATA_HOME"
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

  # isolated env: the deck home is pinned via AGENT_DECK_HOME, FLOX_AI_DIR set
  grep -qx "AGENT_DECK_HOME=$config_dir/agents/agent-deck" "$REC_ENV"
  grep -qx "FLOX_AI_DIR=$config_dir" "$REC_ENV"
  grep -qx 'FLOX_AI=1' "$REC_ENV"

  # XDG must NOT be hijacked -- overriding it would leak the deck home into
  # agent-deck's tmux panes and break unrelated programs. Assert neither XDG
  # var was repointed at the deck home.
  ! grep -qx "XDG_CONFIG_HOME=$config_dir/agents" "$REC_ENV"
  ! grep -qx "XDG_DATA_HOME=$config_dir/agents" "$REC_ENV"

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

# A fake agent-deck that spawns tmux exactly like the real binary
# (new-session -d on the seeded per-env socket) and records a pane's
# environment. This reaches the actual leak path -- the env recorder above
# only sees the agent-deck process env, not what its tmux panes inherit.
make_tmux_probe_deck() {
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  export REC="$BATS_TEST_TMPDIR/deck-rec.txt"
  cat > "$bindir/agent-deck" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  echo "PROC_AGENT_DECK_HOME=$AGENT_DECK_HOME"
  echo "PROC_XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-}"
  echo "PROC_XDG_DATA_HOME=${XDG_DATA_HOME:-}"
} > "$REC"
# socket flox-ai seeded into the deck config (go-toml emits single quotes)
sock="$(sed -n "s/^socket_name = '\(.*\)'/\1/p" "$AGENT_DECK_HOME/config.toml")"
echo "SOCKET=$sock" >> "$REC"
pane="$REC.pane"
tmux -L "$sock" new-session -d -s probe \
  "env | grep -E '^(XDG_CONFIG_HOME|XDG_DATA_HOME|AGENT_DECK_HOME)=' > '$pane'; tmux -L '$sock' wait -S done"
tmux -L "$sock" wait done
sed 's/^/PANE_/' "$pane" >> "$REC"
tmux -L "$sock" kill-server 2>/dev/null || true
EOF
  chmod +x "$bindir/agent-deck"
  export PATH="$bindir:$PATH"
}

@test "launch agent-deck does not leak XDG into tmux panes" {
  command -v tmux >/dev/null || skip "tmux not available"
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  make_tmux_probe_deck

  # sentinel "real" XDG that must survive untouched into the tmux pane
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/real-config"
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/real-data"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

  run flox-ai --dir "$dir" --config-dir "$config_dir" launch agent-deck
  assert_success

  local deck="$config_dir/agents/agent-deck"
  # agent-deck process: deck home pinned via AGENT_DECK_HOME, XDG untouched
  grep -qx "PROC_AGENT_DECK_HOME=$deck" "$REC"
  grep -qx "PROC_XDG_CONFIG_HOME=$XDG_CONFIG_HOME" "$REC"
  grep -qx "PROC_XDG_DATA_HOME=$XDG_DATA_HOME" "$REC"

  # the leak test: the tmux pane inherits the host XDG, NOT the deck home --
  # overriding XDG (the old bug) would surface the deck home here and break
  # unrelated programs in the pane.
  grep -qx "PANE_XDG_CONFIG_HOME=$XDG_CONFIG_HOME" "$REC"
  grep -qx "PANE_XDG_DATA_HOME=$XDG_DATA_HOME" "$REC"
  grep -qx "PANE_AGENT_DECK_HOME=$deck" "$REC"
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

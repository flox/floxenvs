#!/usr/bin/env bats

load test_helper/common

# ── General robustness ────────────────────────────────

@test "empty fragment directory succeeds" {
  local dir
  dir="$(setup_fixtures empty)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_success
}

@test "partial fragment tree (rules only)" {
  local dir
  dir="$(setup_fixtures partial)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_success
  assert_output --partial 'only'
}

@test "special characters in directory name" {
  local dir
  dir="$(setup_fixtures special-chars)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_success
}

@test "unreadable fragment file" {
  local dir
  dir="$(setup_fixtures unreadable)"
  chmod 000 "$dir/rules/secret.md"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  # restore so bats can clean up
  chmod 644 "$dir/rules/secret.md"
  assert_output --partial 'not readable'
}

@test "broken symlink in config dir" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  mkdir -p "$config_dir/rules"
  ln -sfn "/nonexistent/target" "$config_dir/rules/stale.md"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" \
      --config-dir "$config_dir" setup-hook
  else
    run_cm setup-hook
  fi
  assert_success
}

# ── Shell injection via fragment names ────────────────

@test "shell injection: dollar-paren in rule name" {
  local dir config_dir marker
  dir="$BATS_TEST_TMPDIR/inject"
  marker="$BATS_TEST_TMPDIR/pwned"
  mkdir -p "$dir/rules"
  # create file with $() in name using printf for the path
  local malicious
  malicious="$dir/rules/\$(touch ${marker}).md"
  printf '%s' "# Injected" > "$malicious" 2>/dev/null || skip "filesystem cannot create this filename"
  config_dir="$(setup_config_dir)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    local code
    code="$(claude-managed --dir "$dir" \
      --config-dir "$config_dir" setup-hook 2>/dev/null)"
    eval "$code" 2>/dev/null || true
  else
    eval "$(claude-managed setup-hook 2>/dev/null)" \
      2>/dev/null || true
  fi
  [[ ! -f "$marker" ]]
}

@test "shell injection: backtick in rule name" {
  local dir config_dir marker
  dir="$BATS_TEST_TMPDIR/inject-bt"
  marker="$BATS_TEST_TMPDIR/pwned-bt"
  mkdir -p "$dir/rules"
  local malicious
  malicious="$dir/rules/\`touch ${marker}\`.md"
  printf '%s' "# Injected" > "$malicious" 2>/dev/null || skip "filesystem cannot create this filename"
  config_dir="$(setup_config_dir)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    local code
    code="$(claude-managed --dir "$dir" \
      --config-dir "$config_dir" setup-hook 2>/dev/null)"
    eval "$code" 2>/dev/null || true
  else
    eval "$(claude-managed setup-hook 2>/dev/null)" \
      2>/dev/null || true
  fi
  [[ ! -f "$marker" ]]
}

@test "shell injection: semicolon in rule name" {
  local dir config_dir marker
  dir="$BATS_TEST_TMPDIR/inject-sc"
  marker="$BATS_TEST_TMPDIR/pwned-sc"
  mkdir -p "$dir/rules"
  local malicious
  malicious="$dir/rules/;touch ${marker};.md"
  printf '%s' "# Injected" > "$malicious" 2>/dev/null || skip "filesystem cannot create this filename"
  config_dir="$(setup_config_dir)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    local code
    code="$(claude-managed --dir "$dir" \
      --config-dir "$config_dir" setup-hook 2>/dev/null)"
    eval "$code" 2>/dev/null || true
  else
    eval "$(claude-managed setup-hook 2>/dev/null)" \
      2>/dev/null || true
  fi
  [[ ! -f "$marker" ]]
}

@test "shell injection: variable expansion in agent name" {
  local dir config_dir
  dir="$BATS_TEST_TMPDIR/inject-var"
  mkdir -p "$dir/agents"
  local malicious="$dir/agents/\$HOME.md"
  printf '%s\n' '---' 'name: test' '---' '# Agent' > "$malicious" 2>/dev/null || skip "filesystem cannot create this filename"
  config_dir="$(setup_config_dir)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" \
      --config-dir "$config_dir" setup-hook
  else
    run_cm setup-hook
  fi
  assert_success
}

# ── Path traversal ────────────────────────────────────

@test "path traversal: symlink in share dir pointing outside" {
  local dir config_dir
  dir="$BATS_TEST_TMPDIR/symlink-escape"
  mkdir -p "$dir/rules"
  ln -sfn /etc/passwd "$dir/rules/escape.md"
  config_dir="$(setup_config_dir)"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  [[ $status -le 1 ]]
}

# ── Cleanup safety ────────────────────────────────────

@test "cleanup preserves user-created files" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  export FLOX_ENV="$(dirname "$(dirname "$dir")")"
  eval "$(claude-managed --dir "$dir" \
    --config-dir "$config_dir" setup-hook 2>/dev/null)"
  eval "$(claude-managed --dir "$dir" \
    --config-dir "$config_dir" setup-profile 2>/dev/null)"
  echo "user" > "$CLAUDE_CONFIG_DIR/rules/my-custom.md"
  mkdir -p "$CLAUDE_CONFIG_DIR/rules"
  ln -sfn /tmp "$CLAUDE_CONFIG_DIR/rules/user-link"
  _claude_managed_cleanup
  [[ -f "$CLAUDE_CONFIG_DIR/rules/my-custom.md" ]]
  [[ -L "$CLAUDE_CONFIG_DIR/rules/user-link" ]]
}

@test "cleanup preserves non-symlink file with managed name" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  export FLOX_ENV="$(dirname "$(dirname "$dir")")"
  eval "$(claude-managed --dir "$dir" \
    --config-dir "$config_dir" setup-hook 2>/dev/null)"
  eval "$(claude-managed --dir "$dir" \
    --config-dir "$config_dir" setup-profile 2>/dev/null)"
  rm -f "$CLAUDE_CONFIG_DIR/rules/valid.md"
  echo "user override" > "$CLAUDE_CONFIG_DIR/rules/valid.md"
  _claude_managed_cleanup
  [[ -f "$CLAUDE_CONFIG_DIR/rules/valid.md" ]]
  grep -q "user override" "$CLAUDE_CONFIG_DIR/rules/valid.md"
}

# ── Config dir boundary ───────────────────────────────

@test "config dir with existing user content" {
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  mkdir -p "$config_dir/rules"
  echo "existing" > "$config_dir/rules/existing.md"
  export FLOX_ENV="$(dirname "$(dirname "$dir")")"
  eval "$(claude-managed --dir "$dir" \
    --config-dir "$config_dir" setup-hook 2>/dev/null)"
  [[ -f "$config_dir/rules/existing.md" ]]
  grep -q "existing" "$config_dir/rules/existing.md"
}

# ── Symlink attacks ───────────────────────────────────

@test "circular symlink in share dir does not hang" {
  local dir
  dir="$BATS_TEST_TMPDIR/circular"
  mkdir -p "$dir/rules"
  ln -sfn "$dir/rules/a.md" "$dir/rules/b.md"
  ln -sfn "$dir/rules/b.md" "$dir/rules/a.md"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run timeout 10 claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run timeout 10 claude-managed doctor
  fi
  [[ $status -ne 124 ]]
}

@test "broken symlink in share dir does not crash" {
  local dir
  dir="$BATS_TEST_TMPDIR/broken-share"
  mkdir -p "$dir/rules"
  ln -sfn "/nonexistent/file.md" "$dir/rules/broken.md"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  [[ $status -le 1 ]]
}

# ── Frontmatter exploitation ─────────────────────────

@test "extremely long frontmatter value does not crash" {
  local dir
  dir="$BATS_TEST_TMPDIR/long-fm"
  mkdir -p "$dir/rules"
  {
    echo "---"
    printf 'paths: '
    head -c 10240 /dev/urandom | base64 | tr -d '\n'
    echo ""
    echo "---"
    echo "# Long rule"
  } > "$dir/rules/long.md"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  [[ $status -le 1 ]]
}

@test "binary content in frontmatter does not crash" {
  local dir
  dir="$BATS_TEST_TMPDIR/binary-fm"
  mkdir -p "$dir/rules"
  {
    echo "---"
    printf 'paths: \x00\x01\x02\x03'
    echo ""
    echo "---"
    echo "# Binary rule"
  } > "$dir/rules/binary.md"
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  [[ $status -le 1 ]]
}

@test "duplicate keys in frontmatter does not crash" {
  local dir
  dir="$BATS_TEST_TMPDIR/dup-fm"
  mkdir -p "$dir/rules"
  cat > "$dir/rules/dup.md" <<'EOF'
---
paths: src/
paths: lib/
---

# Duplicate keys
EOF
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  [[ $status -le 1 ]]
}

@test "nested YAML in frontmatter does not bypass validation" {
  local dir
  dir="$BATS_TEST_TMPDIR/nested-fm"
  mkdir -p "$dir/agents"
  cat > "$dir/agents/nested.md" <<'EOF'
---
name: nested
hooks:
  pre: "malicious"
  post: "malicious"
---

# Nested agent
EOF
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_output --partial 'forbidden frontmatter key'
}

# ── Resource exhaustion ───────────────────────────────

@test "1000 fragment files do not cause timeout" {
  local dir
  dir="$BATS_TEST_TMPDIR/many"
  mkdir -p "$dir/rules"
  for i in $(seq 1 1000); do
    echo "# Rule $i" > "$dir/rules/rule-$i.md"
  done
  if [[ "$TEST_MODE" == "nix" ]]; then
    run timeout 30 claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run timeout 30 claude-managed doctor
  fi
  assert_success
  [[ $status -ne 124 ]]
}

@test "deeply nested skill directory is handled" {
  local dir
  dir="$BATS_TEST_TMPDIR/deep"
  mkdir -p "$dir/skills/a/b/c/d/e/f/g/h/i/j"
  cat > "$dir/skills/a/SKILL.md" <<'EOF'
---
name: a
description: top level skill
---

# Skill A
EOF
  if [[ "$TEST_MODE" == "nix" ]]; then
    run claude-managed --dir "$dir" doctor
  else
    CM_DIR="$dir" run_cm doctor
  fi
  assert_success
}

# ── Keychain safety (Darwin only) ────────────────────

@test "keychain bridge computes hash from CLAUDE_CONFIG_DIR" {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    skip "keychain tests are macOS-only"
  fi
  local dir config_dir
  dir="$(setup_fixtures)"
  config_dir="$(setup_config_dir)"
  local code
  if [[ "$TEST_MODE" == "nix" ]]; then
    code="$(claude-managed --dir "$dir" \
      --config-dir "$config_dir" setup-hook 2>/dev/null)"
  else
    code="$(claude-managed setup-hook 2>/dev/null)"
  fi
  # The emitted code computes hash dynamically via shasum
  echo "$code" | grep -q 'shasum -a 256'
  # Verify the service name pattern uses the hash
  echo "$code" | grep -q 'Claude Code-credentials-'
}

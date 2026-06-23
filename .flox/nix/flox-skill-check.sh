# Sourced helper (not a package): defines flox_skill_check, a BUILD-TIME hard
# gate that fails a skill package's build when it violates packaging-hygiene
# rules. Sibling of flox-agent-layout.sh and inlined the same way (via
# builtins.readFile) so it runs on the native builder during postInstall.
#
# Usage in a package's postInstall, AFTER flox_agent_layout has run:
#   ${builtins.readFile ../../nix/flox-skill-check.sh}
#   flox_skill_check "$out"
#
# Takes the package's $out and returns non-zero (failing the build) on any
# violation, printing a clear "flox_skill_check: <detail>" line per violation
# to stderr. Needs jq for the LSP command check.
#
# Layout note: the bad shared bin lives at $out/bin, while skill content lives
# at $out/share/flox/<agent>/<plugin>/... (flox_agent_layout operates on
# $out/share). So bin and content sit at DIFFERENT levels — the gate checks
# $out/bin for rule 1 and $out/share for rules 2-4.
#
# Rules enforced (matching the invariants Tasks 1-3 established):
#   1. No shared bin: $out/bin must not exist or be empty. Tools must be
#      referenced by absolute store path, not a shared bin.
#   2. share is flox-only: under $out/share, only the launch layout (flox/)
#      ships; any other per-agent tree (claude-code, opencode, ...) is a
#      violation.
#   3. LSP command absolute: every .lsp.json server .command is an absolute
#      path (starts with /), never a bare PATH-resolved name.
#   4. No PATH-dependent shebangs: shipped EXECUTABLE *.py / *.sh scripts must
#      use an absolute store-path shebang, not "#!/usr/bin/env x" or a bare
#      "#!name". Only executable files are checked — a non-executable file's
#      shebang is inert (it is read, imported, or run via an explicit
#      interpreter like `python3 foo.py`), so its shebang never resolves a
#      PATH and flagging it would be a false positive.
flox_skill_check() {
  local out="$1" fail=0
  [ -n "$out" ] || { echo "flox_skill_check: out dir required" >&2; return 2; }

  # 1. No shared bin.
  if [ -d "$out/bin" ] && [ -n "$(ls -A "$out/bin" 2>/dev/null)" ]; then
    echo "flox_skill_check: $out/bin must be empty — reference tools by absolute store path, not the shared bin" >&2
    fail=1
  fi

  # 2. Under share, only the flox/ launch layout may ship.
  if [ -d "$out/share" ]; then
    local d
    for d in "$out/share"/*; do
      [ -e "$d" ] || continue
      [ "$(basename "$d")" = "flox" ] && continue
      echo "flox_skill_check: $d — only share/flox may ship" >&2
      fail=1
    done
  fi

  # 3. Every .lsp.json server .command must be an absolute path.
  local j
  while IFS= read -r j; do
    if ! jq -e 'to_entries | all(.value.command | startswith("/"))' "$j" >/dev/null 2>&1; then
      echo "flox_skill_check: $j — server .command must be an absolute store path" >&2
      fail=1
    fi
  done < <(find "$out/share/flox" -name '.lsp.json' 2>/dev/null)

  # 4. No PATH-dependent interpreter shebangs in shipped EXECUTABLE scripts.
  #    Non-executable files are skipped: their shebang never runs.
  local s
  while IFS= read -r s; do
    if head -1 "$s" 2>/dev/null | grep -qE '^#!/usr/bin/env |^#![a-zA-Z]'; then
      echo "flox_skill_check: $s — shebang must be an absolute store path" >&2
      fail=1
    fi
  done < <(find "$out/share/flox" -type f -perm -u+x \( -name '*.py' -o -name '*.sh' \) 2>/dev/null)

  return $fail
}

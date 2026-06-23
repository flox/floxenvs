#!/usr/bin/env bash
set -uo pipefail
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SD/../flox-skill-check.sh"
P=0 F=0
ok(){ if [ "$2" = "$3" ]; then P=$((P+1)); echo "ok - $1"; else F=$((F+1)); echo "FAIL - $1 ($2 != $3)"; fi; }

# Fixtures mirror a real package $out: bad bin at $out/bin, skill content at
# $out/share/flox/<agent>/<plugin>/... (flox_agent_layout lays out $out/share).

# clean tree passes
t=$(mktemp -d); mkdir -p "$t/share/flox/claude/x/.claude-plugin"
flox_skill_check "$t" >/dev/null 2>&1; ok "clean passes" "$?" "0"

# $out/bin fails
t=$(mktemp -d); mkdir -p "$t/bin" "$t/share/flox"; : > "$t/bin/python3"
flox_skill_check "$t" >/dev/null 2>&1; ok "bin fails" "$?" "1"

# non-flox share dir fails
t=$(mktemp -d); mkdir -p "$t/share/flox" "$t/share/opencode"
flox_skill_check "$t" >/dev/null 2>&1; ok "non-flox share fails" "$?" "1"

# bare lsp command fails
t=$(mktemp -d); mkdir -p "$t/share/flox/claude/x"
printf '{"clangd":{"command":"clangd"}}' > "$t/share/flox/claude/x/.lsp.json"
flox_skill_check "$t" >/dev/null 2>&1; ok "bare lsp command fails" "$?" "1"

# absolute lsp command passes
t=$(mktemp -d); mkdir -p "$t/share/flox/claude/x"
printf '{"clangd":{"command":"/nix/store/z/bin/clangd"}}' > "$t/share/flox/claude/x/.lsp.json"
flox_skill_check "$t" >/dev/null 2>&1; ok "abs lsp command passes" "$?" "0"

# env-shebang script fails
t=$(mktemp -d); mkdir -p "$t/share/flox/claude/x/scripts"
printf '#!/usr/bin/env python3\n' > "$t/share/flox/claude/x/scripts/a.py"
flox_skill_check "$t" >/dev/null 2>&1; ok "env shebang fails" "$?" "1"

echo "--- $P passed, $F failed"; [ "$F" -eq 0 ]

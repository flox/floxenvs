#!/usr/bin/env bash
# Regression: a scoring tool that CRASHES (nonzero exit, no valid JSON) must
# fail CLOSED — its quality member scores 0 and its check is pass:false with a
# "<tool> failed to run" note — NOT fail open to a perfect 100. This is the
# reviewer's repro: a stub skill-validator that prints to stderr and exits 2.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$DIR/bin/skills-review"
ROOT="$(cd "$DIR/../../.." && pwd)"   # repo root holding the result-* symlinks
SKILL="$DIR/test/skills/good"

# This test needs the real tools (so the guard runs against actual output).
# Assemble a PATH from the built result-*/bin dirs; skip if any are missing.
real_path=""
for r in skill-tools skill-validator claudelint cclint agnix skillcheck; do
  bindir="$ROOT/result-$r/bin"
  if [ ! -x "$bindir/$r" ]; then
    echo "SKIP failclosed (missing result-$r; run: flox build $r)"
    exit 0
  fi
  real_path="$real_path:$bindir"
done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Fake skill-validator: crash exactly like the reviewer's repro.
cat > "$tmp/skill-validator" <<'EOF'
#!/usr/bin/env bash
echo "boom: validator exploded" >&2
exit 2
EOF
chmod +x "$tmp/skill-validator"

# Fake bin FIRST so it shadows the real skill-validator; keep ambient PATH for
# jq/python3/awk/etc. used by the runner.
run_audit() { PATH="$1:$real_path:$PATH" "$BIN" audit --json "$SKILL"; }

# Baseline: all real tools -> skill-validator scores normally. The prepended
# dir doesn't exist, so nothing shadows the real skill-validator.
base="$(run_audit "$tmp/noop_nonexistent_dir" 2>/dev/null || true)"
base_overall="$(echo "$base" | jq -r '.overall')"

# Crashing skill-validator on PATH.
out="$(run_audit "$tmp" 2>/dev/null)"
sv="$(echo "$out" | jq -c '.quality.checks[]|select(.id=="skill-validator")')"
overall="$(echo "$out" | jq -r '.overall')"

# The crashed member must be pass:false with the explicit failure note.
echo "$sv" | jq -e '.pass == false' >/dev/null \
  || { echo "FAIL failclosed: skill-validator should be pass:false, got $sv"; exit 1; }
echo "$sv" | jq -e '.note == "skill-validator failed to run"' >/dev/null \
  || { echo "FAIL failclosed: note should be 'skill-validator failed to run', got $sv"; exit 1; }

# It must NOT fail open to 100; the old bug surfaced note:"100", pass:true.
echo "$sv" | jq -e '.note != "100"' >/dev/null \
  || { echo "FAIL failclosed: skill-validator surfaced 100 (fail OPEN)"; exit 1; }

# A crashed scoring tool drags the overall down vs. the all-real baseline.
[ "$overall" -lt "$base_overall" ] \
  || { echo "FAIL failclosed: overall ($overall) not reduced vs baseline ($base_overall)"; exit 1; }

echo "PASS failclosed (crashed skill-validator: pass:false, overall $overall < baseline $base_overall)"

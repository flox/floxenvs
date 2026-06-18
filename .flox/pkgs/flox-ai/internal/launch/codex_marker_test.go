package launch

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCodexCheck_PatchedAndUnpatched(t *testing.T) {
	dir := t.TempDir()

	patched := filepath.Join(dir, "codex-patched")
	if err := os.WriteFile(patched, []byte("....CODEX_FLOX_SKILL_ROOTS...."), 0o755); err != nil {
		t.Fatal(err)
	}
	unpatched := filepath.Join(dir, "codex-stock")
	if err := os.WriteFile(unpatched, []byte("a stock codex binary"), 0o755); err != nil {
		t.Fatal(err)
	}

	var a codexAdapter
	if got := a.Check(patched); got.Level != OK {
		t.Fatalf("patched: level=%d reason=%q, want OK", got.Level, got.Reason)
	}
	got := a.Check(unpatched)
	if got.Level != Degraded {
		t.Fatalf("unpatched: level=%d, want Degraded", got.Level)
	}
	if got.Reason == "" {
		t.Fatalf("unpatched: empty reason")
	}
}

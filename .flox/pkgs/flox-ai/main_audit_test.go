package main

import (
	"os"
	"strings"
	"testing"
)

// Flags after the <path> argument must be honored (interspersed parsing).
func TestRunAudit_FlagsAfterPath(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	dir := t.TempDir()
	if err := os.WriteFile(dir+"/SKILL.md", []byte("---\nname: x\ndescription: y\n---\n# x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	var out, errw strings.Builder
	// path first, then a high threshold → must exit nonzero.
	code := runAudit([]string{dir, "--kind", "skill", "--threshold", "200"}, &out, &errw)
	if code == 0 {
		t.Fatalf("threshold after path was ignored; got exit 0, stderr=%s out=%s", errw.String(), out.String())
	}
}

// `flox-ai audit <skill> --json` emits a JSON document with an overall score.
// Runs under dry-run so no external tools are needed.
func TestRunAudit_JSON(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	dir := t.TempDir()
	if err := os.WriteFile(dir+"/SKILL.md", []byte("---\nname: x\ndescription: y\n---\n# x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	var out, errw strings.Builder
	code := runAudit([]string{"--json", "--kind", "skill", dir}, &out, &errw)
	if code != 0 {
		t.Fatalf("exit %d, stderr=%s", code, errw.String())
	}
	if !strings.Contains(out.String(), "\"overall\"") {
		t.Errorf("expected overall in JSON, got %s", out.String())
	}
}

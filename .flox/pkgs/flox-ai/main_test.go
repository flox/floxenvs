package main

import (
	"os"
	"path/filepath"
	"testing"
)

// Fragment validation moved out of setup entirely (it lives in `flox-ai
// doctor`). A bad fragment must never cause setup to warn, error, or block
// activation — in any mode.

func TestRunSetup_HookSkipsValidation(t *testing.T) {
	dir := t.TempDir()

	// bad rule (unknown frontmatter key) + skill missing required name:
	// neither must block or fail the hook.
	rulesDir := filepath.Join(dir, "rules")
	os.MkdirAll(rulesDir, 0755)
	os.WriteFile(filepath.Join(rulesDir, "bad.md"), []byte("---\nfoo: bar\n---\n# Bad rule\n"), 0644)

	skillDir := filepath.Join(dir, "skills", "broken")
	os.MkdirAll(skillDir, 0755)
	os.WriteFile(filepath.Join(skillDir, "SKILL.md"),
		[]byte("---\ndescription: x\n---\n# Skill\n"), 0644)

	if err := runSetup(dir, "/tmp/config", "hook"); err != nil {
		t.Fatalf("runSetup failed: %v", err)
	}
}

func TestRunSetup_ProfileSkipsValidation(t *testing.T) {
	dir := t.TempDir()

	rulesDir := filepath.Join(dir, "rules")
	os.MkdirAll(rulesDir, 0755)
	os.WriteFile(filepath.Join(rulesDir, "bad.md"), []byte("---\nfoo: bar\n---\n# Bad\n"), 0644)

	if err := runSetup(dir, "/tmp/config", "profile"); err != nil {
		t.Fatalf("runSetup failed: %v", err)
	}
}

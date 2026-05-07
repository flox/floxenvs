package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunSetup_HookWarnsOnUnknownRuleKey(t *testing.T) {
	dir := t.TempDir()

	// create share/claude-code/rules/ with a rule that has an unknown key
	rulesDir := filepath.Join(dir, "rules")
	os.MkdirAll(rulesDir, 0755)
	os.WriteFile(filepath.Join(rulesDir, "bad.md"), []byte("---\nfoo: bar\n---\n# Bad rule\n"), 0644)

	var warn bytes.Buffer
	err := runSetup(dir, "/tmp/config", "hook", &warn)
	if err != nil {
		t.Fatalf("runSetup failed: %v", err)
	}

	if !strings.Contains(warn.String(), "WARN") {
		t.Errorf("expected WARN on stderr, got: %q", warn.String())
	}
	if !strings.Contains(warn.String(), "unknown frontmatter key") {
		t.Errorf("expected 'unknown frontmatter key' in warning, got: %q", warn.String())
	}
}

func TestRunSetup_HookErrorsOnMissingSkillName(t *testing.T) {
	dir := t.TempDir()

	// skill with frontmatter but no name → error severity
	skillDir := filepath.Join(dir, "skills", "broken")
	os.MkdirAll(skillDir, 0755)
	os.WriteFile(filepath.Join(skillDir, "SKILL.md"),
		[]byte("---\ndescription: x\n---\n# Skill\n"), 0644)

	var warn bytes.Buffer
	err := runSetup(dir, "/tmp/config", "hook", &warn)
	if err != nil {
		t.Fatalf("runSetup failed: %v", err)
	}

	if !strings.Contains(warn.String(), "ERROR") {
		t.Errorf("expected ERROR prefix for missing name, got: %q", warn.String())
	}
}

func TestRunSetup_HookNoWarningsForValid(t *testing.T) {
	dir := t.TempDir()

	// create share/claude-code/rules/ with a valid rule
	rulesDir := filepath.Join(dir, "rules")
	os.MkdirAll(rulesDir, 0755)
	os.WriteFile(filepath.Join(rulesDir, "good.md"), []byte("# Good rule\nDo things.\n"), 0644)

	var warn bytes.Buffer
	err := runSetup(dir, "/tmp/config", "hook", &warn)
	if err != nil {
		t.Fatalf("runSetup failed: %v", err)
	}

	if warn.Len() != 0 {
		t.Errorf("expected no warnings, got: %q", warn.String())
	}
}

func TestRunSetup_ProfileSkipsValidation(t *testing.T) {
	dir := t.TempDir()

	// create share/claude-code/rules/ with a bad rule
	rulesDir := filepath.Join(dir, "rules")
	os.MkdirAll(rulesDir, 0755)
	os.WriteFile(filepath.Join(rulesDir, "bad.md"), []byte("---\nfoo: bar\n---\n# Bad\n"), 0644)

	var warn bytes.Buffer
	err := runSetup(dir, "/tmp/config", "profile", &warn)
	if err != nil {
		t.Fatalf("runSetup failed: %v", err)
	}

	if warn.Len() != 0 {
		t.Errorf("profile should not validate, got warnings: %q", warn.String())
	}
}

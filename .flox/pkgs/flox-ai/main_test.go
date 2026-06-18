package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestAgentPassthrough(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want []string
	}{
		{"no args", []string{"launch", "claude"}, nil},
		{"plain flag", []string{"launch", "claude", "-c"}, []string{"-c"}},
		{"strips delimiter", []string{"launch", "claude", "--", "--session-id", "X"}, []string{"--session-id", "X"}},
		{"deck path", []string{"launch", "agent-deck", "--", "status"}, []string{"status"}},
		{"only first dash-dash stripped", []string{"launch", "claude", "--", "--"}, []string{"--"}},
		{"none", []string{"launch"}, nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := agentPassthrough(c.args); !reflect.DeepEqual(got, c.want) {
				t.Fatalf("got %#v want %#v", got, c.want)
			}
		})
	}
}

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

func TestResolveConfigDir(t *testing.T) {
	cases := []struct {
		name      string
		flag, env string
		project   string
		want      string
	}{
		{"flag wins", "/explicit", "/envdir", "/proj", "/explicit"},
		{"env over default", "", "/envdir", "/proj", "/envdir"},
		{"default", "", "", "/proj", "/proj/.flox/cache/flox-ai"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := resolveConfigDir(c.flag, c.env, c.project); got != c.want {
				t.Fatalf("got %q want %q", got, c.want)
			}
		})
	}
}

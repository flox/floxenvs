package launch

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPiAdapter_Identity(t *testing.T) {
	var a piAdapter
	if a.Name() != "pi" || a.InstallPkg() != "pi" {
		t.Fatalf("identity wrong: %q / %q", a.Name(), a.InstallPkg())
	}
	if a.Check("/bin/pi").Level != OK {
		t.Fatalf("Check not OK")
	}
}

func TestPiAdapter_Build(t *testing.T) {
	share := t.TempDir()
	skillDir := filepath.Join(share, "skills", "demo")
	if err := os.MkdirAll(skillDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(skillDir, "SKILL.md"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	rulesDir := filepath.Join(share, "rules")
	if err := os.MkdirAll(rulesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	rulePath := filepath.Join(rulesDir, "r.md")
	if err := os.WriteFile(rulePath, []byte("R"), 0o644); err != nil {
		t.Fatal(err)
	}

	ctx := Context{
		Bin:         "/env/bin/pi",
		ShareDir:    share,
		LaunchDir:   filepath.Join(t.TempDir(), "launch", "pi"),
		ConfigDir:   t.TempDir(),
		Passthrough: []string{"--print", "hi"},
		BaseEnv:     []string{"HOME=/h"},
	}

	var a piAdapter
	spec, err := a.Build(ctx)
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(spec.Argv, " ")
	if spec.Argv[0] != "/env/bin/pi" {
		t.Fatalf("argv[0]=%v", spec.Argv)
	}
	if !strings.Contains(joined, "--skill "+skillDir) {
		t.Fatalf("argv missing --skill %s: %v", skillDir, spec.Argv)
	}
	if !strings.Contains(joined, "--append-system-prompt "+rulePath) {
		t.Fatalf("argv missing rule: %v", spec.Argv)
	}
	if spec.Argv[len(spec.Argv)-2] != "--print" || spec.Argv[len(spec.Argv)-1] != "hi" {
		t.Fatalf("passthrough not last: %v", spec.Argv)
	}
}

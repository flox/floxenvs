package launch

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestOpencodeAdapter_Identity(t *testing.T) {
	var a opencodeAdapter
	if a.Name() != "opencode" || a.InstallPkg() != "opencode" {
		t.Fatalf("identity wrong: %q / %q", a.Name(), a.InstallPkg())
	}
	if a.Check("/bin/opencode").Level != OK {
		t.Fatalf("Check not OK")
	}
}

func TestOpencodeAdapter_Build(t *testing.T) {
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

	launchDir := filepath.Join(t.TempDir(), "launch", "opencode")
	ctx := Context{
		Bin:       "/env/bin/opencode",
		ShareDir:  share,
		LaunchDir: launchDir,
		ConfigDir: t.TempDir(),
		BaseEnv:   []string{"HOME=/h"},
	}

	var a opencodeAdapter
	spec, err := a.Build(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if spec.Argv[0] != "/env/bin/opencode" {
		t.Fatalf("argv[0]=%v", spec.Argv)
	}

	var content string
	for _, e := range spec.Env {
		if strings.HasPrefix(e, "OPENCODE_CONFIG_CONTENT=") {
			content = strings.TrimPrefix(e, "OPENCODE_CONFIG_CONTENT=")
		}
	}
	if content == "" {
		t.Fatalf("env missing OPENCODE_CONFIG_CONTENT: %v", spec.Env)
	}

	var cfg struct {
		Skills struct {
			Paths []string `json:"paths"`
		} `json:"skills"`
		Instructions []string `json:"instructions"`
	}
	if err := json.Unmarshal([]byte(content), &cfg); err != nil {
		t.Fatalf("config not valid JSON: %v", err)
	}
	if len(cfg.Skills.Paths) != 1 || cfg.Skills.Paths[0] != filepath.Join(launchDir, "skills") {
		t.Fatalf("skills.paths=%v", cfg.Skills.Paths)
	}
	if len(cfg.Instructions) != 1 || cfg.Instructions[0] != rulePath {
		t.Fatalf("instructions=%v", cfg.Instructions)
	}
}

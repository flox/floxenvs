package launch

import (
	"os"
	"path/filepath"
	"testing"

	"flox.dev/flox-ai/internal/discover"
)

func TestBuildCodexSkillRoot_None(t *testing.T) {
	got, err := BuildCodexSkillRoot(t.TempDir(), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	if got != "" {
		t.Fatalf("want empty root, got %q", got)
	}
}

func TestBuildCodexSkillRoot_SkillsAndAgents(t *testing.T) {
	src := t.TempDir()

	// A skill is a directory holding SKILL.md.
	skillDir := filepath.Join(src, "myskill")
	if err := os.MkdirAll(skillDir, 0755); err != nil {
		t.Fatal(err)
	}
	skillMD := filepath.Join(skillDir, "SKILL.md")
	if err := os.WriteFile(skillMD, []byte("# skill\n"), 0644); err != nil {
		t.Fatal(err)
	}

	// A standalone agent is a bare .md file.
	agentMD := filepath.Join(src, "myagent.md")
	if err := os.WriteFile(agentMD, []byte("# agent\n"), 0644); err != nil {
		t.Fatal(err)
	}

	launchDir := t.TempDir()
	root, err := BuildCodexSkillRoot(launchDir,
		[]discover.Fragment{{Name: "myskill", Path: skillMD}},
		[]discover.Fragment{{Name: "myagent", Path: agentMD}},
	)
	if err != nil {
		t.Fatal(err)
	}
	if root == "" {
		t.Fatal("want non-empty root")
	}

	// Skill links its directory; the linked dir must carry SKILL.md.
	if _, err := os.Stat(filepath.Join(root, "myskill", "SKILL.md")); err != nil {
		t.Fatalf("skill not linked: %v", err)
	}
	// Agent is wrapped as <name>/SKILL.md.
	if _, err := os.Stat(filepath.Join(root, "myagent", "SKILL.md")); err != nil {
		t.Fatalf("agent not wrapped as skill: %v", err)
	}
}

func TestPrepareCodex_Wipes(t *testing.T) {
	launchDir := filepath.Join(t.TempDir(), "codex")
	// Pre-seed a stale entry that must be wiped.
	if err := os.MkdirAll(filepath.Join(launchDir, "skills", "stale"), 0755); err != nil {
		t.Fatal(err)
	}

	skillRoot, rulesFile, err := PrepareCodex(launchDir, &discover.Result{})
	if err != nil {
		t.Fatal(err)
	}
	if skillRoot != "" || rulesFile != "" {
		t.Fatalf("want empty outputs for no fragments, got %q / %q", skillRoot, rulesFile)
	}
	if _, err := os.Stat(filepath.Join(launchDir, "skills", "stale")); !os.IsNotExist(err) {
		t.Fatal("stale entry was not wiped")
	}
}

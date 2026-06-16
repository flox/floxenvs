package launch

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"flox.dev/flox-ai/internal/discover"
)

func TestPlanArgv_Full(t *testing.T) {
	p := Plan{
		Bin:         "/env/bin/claude",
		SynthPlugin: "/cfg/launch/plugin",
		Plugins:     []string{"/env/p1", "/cfg/plugins/p2"},
		RulesFile:   "/cfg/launch/rules.md",
		Passthrough: []string{"-p", "hi"},
	}
	want := []string{
		"/env/bin/claude",
		"--plugin-dir", "/cfg/launch/plugin",
		"--plugin-dir", "/env/p1",
		"--plugin-dir", "/cfg/plugins/p2",
		"--append-system-prompt-file", "/cfg/launch/rules.md",
		"-p", "hi",
	}
	if got := p.Argv(); !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}

func TestPlanArgv_Minimal(t *testing.T) {
	p := Plan{Bin: "/env/bin/claude"}
	want := []string{"/env/bin/claude"}
	if got := p.Argv(); !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}

func TestPlanArgv_NoSynthNoRules(t *testing.T) {
	p := Plan{Bin: "/b", Plugins: []string{"/p1"}, Passthrough: []string{"--continue"}}
	want := []string{"/b", "--plugin-dir", "/p1", "--continue"}
	if got := p.Argv(); !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}

func TestSupportedNames(t *testing.T) {
	if got := SupportedNames(); got != "claude" {
		t.Fatalf("got %q want %q", got, "claude")
	}
}

func TestMergeRules_None(t *testing.T) {
	got, err := MergeRules(t.TempDir(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if got != "" {
		t.Fatalf("want empty path, got %q", got)
	}
}

func TestMergeRules_ConcatOrderAndHeaders(t *testing.T) {
	src := t.TempDir()
	if err := os.WriteFile(filepath.Join(src, "a.md"), []byte("AAA"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "b.md"), []byte("BBB\n"), 0644); err != nil {
		t.Fatal(err)
	}
	rules := []discover.Fragment{
		{Name: "a", Path: filepath.Join(src, "a.md")},
		{Name: "b", Path: filepath.Join(src, "b.md")},
	}
	launchDir := t.TempDir()
	out, err := MergeRules(launchDir, rules)
	if err != nil {
		t.Fatal(err)
	}
	if out != filepath.Join(launchDir, "rules.md") {
		t.Fatalf("unexpected out path %q", out)
	}
	got, err := os.ReadFile(out)
	if err != nil {
		t.Fatal(err)
	}
	want := "<!-- source: a -->\nAAA\n\n<!-- source: b -->\nBBB\n\n"
	if string(got) != want {
		t.Fatalf("got %q want %q", got, want)
	}
}

func TestBuildSynthPlugin_None(t *testing.T) {
	got, err := BuildSynthPlugin(t.TempDir(), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	if got != "" {
		t.Fatalf("want empty path, got %q", got)
	}
}

func TestBuildSynthPlugin_SkillsAndAgents(t *testing.T) {
	src := t.TempDir()

	skillDir := filepath.Join(src, "skills", "demo")
	if err := os.MkdirAll(skillDir, 0755); err != nil {
		t.Fatal(err)
	}
	skillFile := filepath.Join(skillDir, "SKILL.md")
	if err := os.WriteFile(skillFile, []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}

	agentFile := filepath.Join(src, "agents", "rev.md")
	if err := os.MkdirAll(filepath.Dir(agentFile), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(agentFile, []byte("y"), 0644); err != nil {
		t.Fatal(err)
	}

	launchDir := t.TempDir()
	plugin, err := BuildSynthPlugin(launchDir,
		[]discover.Fragment{{Name: "demo", Path: skillFile}},
		[]discover.Fragment{{Name: "rev", Path: agentFile}},
	)
	if err != nil {
		t.Fatal(err)
	}
	if plugin != filepath.Join(launchDir, "plugin") {
		t.Fatalf("unexpected plugin path %q", plugin)
	}

	meta, err := os.ReadFile(filepath.Join(plugin, ".claude-plugin", "plugin.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(meta), `"name":"flox"`) {
		t.Fatalf("bad plugin.json: %s", meta)
	}

	gotSkill, err := os.Readlink(filepath.Join(plugin, "skills", "demo"))
	if err != nil {
		t.Fatal(err)
	}
	if gotSkill != skillDir {
		t.Fatalf("skill link %q want %q", gotSkill, skillDir)
	}

	gotAgent, err := os.Readlink(filepath.Join(plugin, "agents", "rev.md"))
	if err != nil {
		t.Fatal(err)
	}
	if gotAgent != agentFile {
		t.Fatalf("agent link %q want %q", gotAgent, agentFile)
	}
}

func TestUserPluginDirs_AbsentDir(t *testing.T) {
	got, err := UserPluginDirs(t.TempDir()) // no plugins/ subdir
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Fatalf("want none, got %v", got)
	}
}

func TestUserPluginDirs_SkipsBroken(t *testing.T) {
	configDir := t.TempDir()
	pluginsDir := filepath.Join(configDir, "plugins")
	if err := os.MkdirAll(pluginsDir, 0755); err != nil {
		t.Fatal(err)
	}

	// good: symlink to an existing dir
	realPlugin := filepath.Join(t.TempDir(), "good-plugin")
	if err := os.MkdirAll(realPlugin, 0755); err != nil {
		t.Fatal(err)
	}
	goodLink := filepath.Join(pluginsDir, "good")
	if err := os.Symlink(realPlugin, goodLink); err != nil {
		t.Fatal(err)
	}

	// broken: symlink to a missing target
	if err := os.Symlink(filepath.Join(t.TempDir(), "missing"), filepath.Join(pluginsDir, "bad")); err != nil {
		t.Fatal(err)
	}

	got, err := UserPluginDirs(configDir)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{goodLink}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}

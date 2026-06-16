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

func TestPrepare_BuildsArtifactsAndIsIdempotent(t *testing.T) {
	src := t.TempDir()

	// one rule
	rulesSrc := filepath.Join(src, "rules")
	if err := os.MkdirAll(rulesSrc, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rulesSrc, "r.md"), []byte("R"), 0644); err != nil {
		t.Fatal(err)
	}

	// one skill
	skillDir := filepath.Join(src, "skills", "s")
	if err := os.MkdirAll(skillDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(skillDir, "SKILL.md"), []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}

	frags := &discover.Result{
		Rules:  []discover.Fragment{{Name: "r", Path: filepath.Join(rulesSrc, "r.md")}},
		Skills: []discover.Fragment{{Name: "s", Path: filepath.Join(skillDir, "SKILL.md")}},
	}

	launchDir := filepath.Join(t.TempDir(), "launch")

	// stale file that must be wiped on Prepare
	if err := os.MkdirAll(launchDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(launchDir, "stale.txt"), []byte("old"), 0644); err != nil {
		t.Fatal(err)
	}

	synth, rules, err := Prepare(launchDir, frags)
	if err != nil {
		t.Fatal(err)
	}
	if synth != filepath.Join(launchDir, "plugin") {
		t.Fatalf("synth %q", synth)
	}
	if rules != filepath.Join(launchDir, "rules.md") {
		t.Fatalf("rules %q", rules)
	}
	if _, err := os.Stat(filepath.Join(launchDir, "stale.txt")); !os.IsNotExist(err) {
		t.Fatalf("stale file not wiped")
	}

	// second run: still succeeds (symlinks don't collide because of wipe)
	if _, _, err := Prepare(launchDir, frags); err != nil {
		t.Fatalf("second Prepare failed: %v", err)
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

func TestDedupPluginDirs_SamePluginTwice(t *testing.T) {
	real := t.TempDir() // the actual plugin dir (e.g. share/.../plugins/p)
	link := filepath.Join(t.TempDir(), "p-link")
	if err := os.Symlink(real, link); err != nil {
		t.Fatal(err)
	}
	// env path first (real), user symlink second (resolves to same real)
	got := dedupPluginDirs([]string{real, link})
	want := []string{real}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}

func TestDedupPluginDirs_DistinctKept(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	got := dedupPluginDirs([]string{a, b})
	want := []string{a, b}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}

func TestChildEnv_AddsFloxAINotConfigDir(t *testing.T) {
	env := childEnv()

	var hasFloxAI bool
	for _, kv := range env {
		if kv == "FLOX_AI=1" {
			hasFloxAI = true
		}
	}
	if !hasFloxAI {
		t.Fatal("childEnv missing FLOX_AI=1")
	}

	// childEnv must NOT introduce a CLAUDE_CONFIG_DIR entry that the
	// parent environment didn't already have.
	count := func(list []string) int {
		n := 0
		for _, kv := range list {
			if strings.HasPrefix(kv, "CLAUDE_CONFIG_DIR=") {
				n++
			}
		}
		return n
	}
	if count(env) != count(os.Environ()) {
		t.Fatalf("childEnv changed CLAUDE_CONFIG_DIR entries: parent=%d child=%d",
			count(os.Environ()), count(env))
	}
}

func TestRun_UnknownAgent(t *testing.T) {
	err := Run(Options{AgentName: "bogus"})
	if err == nil {
		t.Fatal("want error for unknown agent")
	}
	if !strings.Contains(err.Error(), "unknown agent") ||
		!strings.Contains(err.Error(), "claude") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestRun_BinaryMissingInEnv(t *testing.T) {
	floxEnv := t.TempDir() // has no bin/claude
	err := Run(Options{
		AgentName: "claude",
		FloxEnv:   floxEnv,
		ShareDir:  filepath.Join(floxEnv, "share", "claude-code"),
		ConfigDir: filepath.Join(t.TempDir(), ".flox-ai"),
	})
	if err == nil {
		t.Fatal("want error for missing binary")
	}
	if !strings.Contains(err.Error(), "claude not found in this Flox environment") {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(err.Error(), `remote = "flox/claude"`) {
		t.Fatalf("error missing fix-it hint: %v", err)
	}
}

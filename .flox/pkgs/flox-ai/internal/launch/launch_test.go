package launch

import (
	"os"
	"path/filepath"
	"reflect"
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

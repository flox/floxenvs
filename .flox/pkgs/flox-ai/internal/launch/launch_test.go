package launch

import (
	"reflect"
	"testing"
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

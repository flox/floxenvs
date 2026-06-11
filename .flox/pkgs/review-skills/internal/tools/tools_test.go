package tools

import (
	"os"
	"path/filepath"
	"testing"

	"flox.dev/review-skills/internal/detect"
)

func names(ts []Tool) map[string]bool {
	m := map[string]bool{}
	for _, t := range ts {
		m[t.Name] = true
	}
	return m
}

func TestDefaultEnsembles(t *testing.T) {
	skill, err := Select(detect.KindSkill, "", "")
	if err != nil {
		t.Fatal(err)
	}
	sn := names(skill)
	if !sn["skill-tools"] || !sn["skill-validator"] || !sn["claudelint"] || sn["skillcheck"] {
		t.Fatalf("skill ensemble wrong: %v", sn)
	}
	agent, err := Select(detect.KindAgent, "", "")
	if err != nil {
		t.Fatal(err)
	}
	an := names(agent)
	if !an["claudelint"] || !an["agnix"] || !an["cclint"] || an["skill-tools"] {
		t.Fatalf("agent ensemble wrong: %v", an)
	}
}

func TestSelectDisable(t *testing.T) {
	got, err := Select(detect.KindSkill, "", "claudelint")
	if err != nil {
		t.Fatal(err)
	}
	if names(got)["claudelint"] {
		t.Fatalf("claudelint should be disabled")
	}
}

func TestSelectTools(t *testing.T) {
	only, err := Select(detect.KindSkill, "skill-tools", "")
	if err != nil || len(only) != 1 || only[0].Name != "skill-tools" {
		t.Fatalf("--tools restrict failed: %v %v", only, err)
	}
}

func TestSelectErrors(t *testing.T) {
	if _, err := Select(detect.KindSkill, "nope", ""); err == nil {
		t.Fatalf("unknown --tools should error")
	}
	if _, err := Select(detect.KindSkill, "", "nope"); err == nil {
		t.Fatalf("unknown --disable should error")
	}
	if _, err := Select(detect.KindSkill, "skill-tools", "claudelint"); err == nil {
		t.Fatalf("--tools + --disable should error")
	}
	if _, err := Select(detect.KindSkill, "", "skill-tools,skill-validator,claudelint"); err == nil {
		t.Fatalf("disabling all should error")
	}
	// skillcheck is a security tool, not selectable as a quality tool.
	if _, err := Select(detect.KindSkill, "skillcheck", ""); err == nil {
		t.Fatalf("security tool should not be a valid quality --tools target")
	}
}

func TestAvailable(t *testing.T) {
	dir := t.TempDir()
	stub := filepath.Join(dir, "faketool")
	if err := os.WriteFile(stub, []byte("#!/bin/sh\necho 1.2.3\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)

	ok := Available(Tool{Name: "faketool", Bin: "faketool"})
	if ok.State != "ok" || ok.Version != "1.2.3" {
		t.Fatalf("available stub: %+v", ok)
	}
	missing := Available(Tool{Name: "nope", Bin: "definitely-not-on-path-xyz"})
	if missing.State != "not-found" {
		t.Fatalf("missing should be not-found: %+v", missing)
	}
}

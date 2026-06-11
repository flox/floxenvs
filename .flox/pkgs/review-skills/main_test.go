package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// invoke runs the CLI in-process under dry-run and returns stdout + exit code.
func invoke(t *testing.T, args ...string) (string, int) {
	t.Helper()
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	var out, errw bytes.Buffer
	code := run(args, &out, &errw)
	return out.String(), code
}

func tmpSkill(t *testing.T) string {
	t.Helper()
	sk := filepath.Join(t.TempDir(), "good")
	if err := os.MkdirAll(sk, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sk, "SKILL.md"),
		[]byte("---\nname: good\ndescription: Use when testing.\n---\n# good\nDo it.\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return sk
}

func TestVersion(t *testing.T) {
	out, code := invoke(t, "version")
	if code != 0 || strings.TrimSpace(out) != "0.1.0" {
		t.Fatalf("version: code=%d out=%q", code, out)
	}
}

func TestNoArgsUsage(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	var out, errw bytes.Buffer
	code := run(nil, &out, &errw)
	if code == 0 {
		t.Fatalf("no args should exit nonzero")
	}
	if !strings.Contains(errw.String(), "Usage:") {
		t.Fatalf("expected usage, got %q", errw.String())
	}
}

func TestAuditJSON(t *testing.T) {
	out, code := invoke(t, "audit", "--json", tmpSkill(t))
	if code != 0 {
		t.Fatalf("audit exit %d: %s", code, out)
	}
	var r map[string]any
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatalf("not JSON: %s", out)
	}
	if r["overall"] == nil || r["quality"] == nil || r["status"] == nil {
		t.Fatalf("missing fields: %s", out)
	}
}

func TestAuditOneLiner(t *testing.T) {
	out, code := invoke(t, "audit", tmpSkill(t))
	if code != 0 {
		t.Fatalf("audit exit %d: %s", code, out)
	}
	if !strings.Contains(out, "skill good:") {
		t.Fatalf("expected one-liner, got %q", out)
	}
}

func TestThresholdExit(t *testing.T) {
	if _, code := invoke(t, "audit", "--threshold", "100", tmpSkill(t)); code == 0 {
		t.Fatalf("threshold 100 should exit nonzero")
	}
	if _, code := invoke(t, "audit", "--threshold", "1", tmpSkill(t)); code != 0 {
		t.Fatalf("threshold 1 should pass")
	}
}

func TestReviewQuality(t *testing.T) {
	out, code := invoke(t, "review", "--json", tmpSkill(t))
	if code != 0 {
		t.Fatalf("review exit %d: %s", code, out)
	}
	var q map[string]any
	if err := json.Unmarshal([]byte(out), &q); err != nil {
		t.Fatalf("review not JSON: %s", out)
	}
	if q["score"] == nil {
		t.Fatalf("review missing score: %s", out)
	}
}

func TestReportNamesTool(t *testing.T) {
	out, code := invoke(t, "report", tmpSkill(t))
	if code != 0 {
		t.Fatalf("report exit %d: %s", code, out)
	}
	if !strings.Contains(out, "skill-tools") {
		t.Fatalf("report should name skill-tools, got %q", out)
	}
}

func TestUnknownTool(t *testing.T) {
	if _, code := invoke(t, "audit", "--tools", "nope", tmpSkill(t)); code == 0 {
		t.Fatalf("unknown --tools should error")
	}
}

func TestDoctorRuns(t *testing.T) {
	// Exit code varies with tool availability in the test env, so assert only
	// that doctor renders its table header and names a known registry tool.
	out, _ := invoke(t, "doctor")
	if !strings.Contains(out, "TOOL") {
		t.Fatalf("doctor should print a table header, got %q", out)
	}
	if !strings.Contains(out, "skill-tools") {
		t.Fatalf("doctor should list skill-tools, got %q", out)
	}
}

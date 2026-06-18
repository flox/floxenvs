package audit

import (
	"os"
	"testing"

	"flox.dev/flox-ai/internal/audit/detect"
)

// With IncludeRaw set, Run must populate RawByTool with an entry for each
// selected quality tool. Uses the dry-run stub path so no real tools are
// required on PATH.
func TestRun_IncludeRaw(t *testing.T) {
	t.Setenv("REVIEW_SKILLS_DRY_RUN", "1")
	dir := t.TempDir()
	if err := os.WriteFile(dir+"/SKILL.md", []byte("---\nname: x\ndescription: y\n---\n# x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	r, err := Run(Options{Path: dir, Kind: detect.KindSkill, IncludeRaw: true})
	if err != nil {
		t.Fatal(err)
	}
	if r.RawByTool == nil {
		t.Fatal("RawByTool is nil with IncludeRaw set")
	}
	if _, ok := r.RawByTool["skill-tools"]; !ok {
		t.Errorf("missing raw for skill-tools; got keys %v", keysOf(r.RawByTool))
	}
}

func keysOf(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

package detect

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDetect(t *testing.T) {
	tmp := t.TempDir()
	sk := filepath.Join(tmp, "sk")
	os.MkdirAll(sk, 0o755)
	os.WriteFile(filepath.Join(sk, "SKILL.md"), []byte("---\nname: x\ndescription: y\n---\n"), 0o644)
	if Detect(sk) != KindSkill {
		t.Errorf("dir with SKILL.md should be skill")
	}
	ag := filepath.Join(tmp, "ag.md")
	os.WriteFile(ag, []byte("---\nname: a\ndescription: d\nmodel: sonnet\ntools: Read\n---\n"), 0o644)
	if Detect(ag) != KindAgent {
		t.Errorf(".md with agent frontmatter should be agent")
	}
}

// A skill whose frontmatter has only skill keys, but whose BODY or a nested
// key mentions "model:", must not be misclassified as an agent. YAML parsing
// (vs line-prefix scanning) makes this robust.
func TestDetectNoFalsePositiveOnBody(t *testing.T) {
	tmp := t.TempDir()
	sk := filepath.Join(tmp, "doc.md")
	os.WriteFile(sk, []byte("---\nname: doc-skill\ndescription: explains how to set model parameters\nmetadata:\n  model: not-a-top-level-key\n---\nThe model: field in the body is prose.\n"), 0o644)
	if Detect(sk) != KindSkill {
		t.Errorf("skill with body/nested 'model:' should stay a skill")
	}
}

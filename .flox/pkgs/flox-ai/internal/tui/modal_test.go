package tui

import (
	"strings"
	"testing"
)

func TestRenderShowsModalOverBase(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 100, 30
	m.stageInstall("claude-code-plugin-caveman")
	m.modal = modalState{kind: modalConfirm, title: "apply changes"}
	out := m.render()
	if !strings.Contains(out, "Apply changes") || !strings.Contains(out, "Caveman") {
		t.Errorf("confirm modal must appear over base; got:\n%s", out)
	}
}

package tui

import (
	"testing"

	tea "charm.land/bubbletea/v2"
)

func keyPress(s string) tea.KeyPressMsg {
	switch s {
	case "enter":
		return tea.KeyPressMsg{Code: tea.KeyEnter}
	case "esc":
		return tea.KeyPressMsg{Code: tea.KeyEsc}
	default:
		return tea.KeyPressMsg{Text: s}
	}
}

func reviewModel() model {
	th := DefaultTheme()
	m := model{width: 100, height: 30, styles: newStyledTheme(th), theme: th}
	m.modal = modalState{kind: modalReview, title: "review skills"}
	m.reviewResults = []auditResult{
		{Kind: "skill", Name: "alpha", Overall: 50, Status: "warn",
			Checks:   []auditCheck{{ID: "skill-tools", Weight: 40, Pass: false}},
			Findings: []auditFinding{{Tool: "skill-tools", Severity: "warning", Rule: "R", Message: "m", File: "f", Line: 3}}},
		{Kind: "skill", Name: "beta", Overall: 90, Status: "good"},
	}
	return m
}

func TestReviewFocusDrill(t *testing.T) {
	m := reviewModel()
	m2, _ := m.handleModalKey(keyPress("l"))
	if m2.(model).reviewFocus != 1 {
		t.Fatalf("focus after l = %d, want 1", m2.(model).reviewFocus)
	}
	m3, _ := m2.(model).handleModalKey(keyPress("h"))
	if m3.(model).reviewFocus != 0 {
		t.Fatalf("focus after h = %d, want 0", m3.(model).reviewFocus)
	}
}

func TestReviewCursorClamp(t *testing.T) {
	m := reviewModel()
	m2, _ := m.handleModalKey(keyPress("j"))
	if got := m2.(model).reviewCur[0]; got != 1 {
		t.Fatalf("cursor after j = %d, want 1", got)
	}
	m3, _ := m2.(model).handleModalKey(keyPress("j"))
	if got := m3.(model).reviewCur[0]; got != 1 {
		t.Fatalf("cursor clamped = %d, want 1 (2 items)", got)
	}
}

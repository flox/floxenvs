package tui

import "testing"

func TestAgentForMapping(t *testing.T) {
	if agentFor("claude") != "claude-code" {
		t.Errorf("claude -> %q", agentFor("claude"))
	}
	if agentFor("codex") != "codex" {
		t.Error("unknown agent maps to itself")
	}
}

func TestAgentMovement(t *testing.T) {
	m := newModel(testItems(), nil, []string{"claude", "codex"},
		nil, nil, nil, nil, "s", "c", "p")
	m.nextAgent()
	if m.currentAgent() != "codex" {
		t.Errorf("next -> %q", m.currentAgent())
	}
	m.nextAgent()
	if m.currentAgent() != "codex" {
		t.Error("clamp at last")
	}
	m.prevAgent()
	if m.currentAgent() != "claude" {
		t.Errorf("prev -> %q", m.currentAgent())
	}
}

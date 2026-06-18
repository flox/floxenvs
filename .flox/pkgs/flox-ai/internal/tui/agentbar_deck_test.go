package tui

import (
	"strings"
	"testing"
)

func TestAgentDeckDisplay(t *testing.T) {
	if got := agentDisplay("agent-deck"); got != "Agent Deck" {
		t.Errorf("agentDisplay(agent-deck) = %q, want %q", got, "Agent Deck")
	}
	title, desc := agentInfo("agent-deck")
	if title != "Agent Deck" || !strings.Contains(desc, "session manager") {
		t.Errorf("agentInfo(agent-deck) = %q / %q", title, desc)
	}
	if !strings.Contains(agentLaunch("agent-deck"), "Agent Deck") {
		t.Errorf("agentLaunch(agent-deck) missing name: %q", agentLaunch("agent-deck"))
	}
	// claude's launch text must no longer claim it is the only supported agent.
	if strings.Contains(agentLaunch("claude"), "Only Claude Code is supported") {
		t.Error("claude launch text still says it is the only supported agent")
	}
}

func TestDefaultAgentIsClaude(t *testing.T) {
	m := newModel(nil, nil, []string{"agent-deck", "claude"},
		nil, nil, ReviewSkills{}, FloxDoctor{}, "", "", "")
	if m.currentAgent() != "claude" {
		t.Errorf("default agent = %q, want claude", m.currentAgent())
	}
}

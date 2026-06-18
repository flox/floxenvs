package tui

import (
	"strings"
	"testing"
)

func TestAgentDisplay_NewAgents(t *testing.T) {
	if agentDisplay("opencode") != "opencode" {
		t.Fatalf("opencode display=%q", agentDisplay("opencode"))
	}
	if agentDisplay("pi") != "pi" {
		t.Fatalf("pi display=%q", agentDisplay("pi"))
	}
}

func TestAgentInfo_NewAgents(t *testing.T) {
	for _, name := range []string{"opencode", "pi"} {
		title, desc := agentInfo(name)
		if title == "" || desc == "" {
			t.Fatalf("%s: empty info (%q/%q)", name, title, desc)
		}
		if title == name && strings.Contains(desc, "AI coding agent.") {
			t.Fatalf("%s: hit default agentInfo branch", name)
		}
	}
}

func TestAgentLaunch_NewAgents(t *testing.T) {
	for _, name := range []string{"opencode", "pi"} {
		if got := agentLaunch(name); strings.HasPrefix(got, "Starts the agent with the installed") {
			t.Fatalf("%s: hit default agentLaunch branch", name)
		}
	}
}

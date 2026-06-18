package tui

import (
	"strings"
	"testing"
)

func TestCodexDisplay(t *testing.T) {
	if got := agentDisplay("codex"); got != "Codex" {
		t.Errorf("agentDisplay(codex) = %q, want %q", got, "Codex")
	}
	title, desc := agentInfo("codex")
	if title != "Codex" || !strings.Contains(desc, "skill roots") {
		t.Errorf("agentInfo(codex) = %q / %q", title, desc)
	}
	launch := agentLaunch("codex")
	if !strings.Contains(launch, "Codex") {
		t.Errorf("agentLaunch(codex) missing name: %q", launch)
	}
	// Codex must advertise that plugins are not injected.
	if !strings.Contains(launch, "Plugins are not injected") {
		t.Errorf("agentLaunch(codex) missing plugin caveat: %q", launch)
	}
}

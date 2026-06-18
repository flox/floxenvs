package tui

import (
	"testing"

	"flox.dev/flox-ai/internal/launch"
)

func TestAgentNamesFromLaunch(t *testing.T) {
	got := agentNames()
	if len(got) != len(launch.Supported) {
		t.Fatalf("agentNames count = %d, want %d", len(got), len(launch.Supported))
	}
	for i := 1; i < len(got); i++ {
		if got[i-1] > got[i] {
			t.Errorf("agentNames not sorted: %v", got)
		}
	}
}

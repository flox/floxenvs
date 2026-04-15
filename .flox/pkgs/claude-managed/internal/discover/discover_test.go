package discover

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

// testdataDir returns the path to the testdata directory relative to this file.
func testdataDir() string {
	_, filename, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(filename), "..", "testdata", "share", "claude")
}

func TestDiscover(t *testing.T) {
	result, err := Scan(testdataDir())
	if err != nil {
		t.Fatalf("Scan returned error: %v", err)
	}

	if got := len(result.Rules); got != 1 {
		t.Errorf("Rules: want 1, got %d", got)
	}
	if got := len(result.Skills); got != 1 {
		t.Errorf("Skills: want 1, got %d", got)
	}
	if got := len(result.Agents); got != 1 {
		t.Errorf("Agents: want 1, got %d", got)
	}

	// Verify skill name
	if len(result.Skills) == 1 && result.Skills[0].Name != "demo" {
		t.Errorf("Skills[0].Name: want demo, got %s", result.Skills[0].Name)
	}

	if got := len(result.Plugins); got != 1 {
		t.Errorf("Plugins: want 1, got %d", got)
	}
	if len(result.Plugins) == 1 && result.Plugins[0].Name != "test-plugin" {
		t.Errorf("Plugins[0].Name: want test-plugin, got %s", result.Plugins[0].Name)
	}

	if result.IsEmpty() {
		t.Error("IsEmpty() should be false")
	}
}

func TestDiscover_Empty(t *testing.T) {
	dir, err := os.MkdirTemp("", "discover-empty-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	result, err := Scan(dir)
	if err != nil {
		t.Fatalf("Scan returned error: %v", err)
	}

	if !result.IsEmpty() {
		t.Error("IsEmpty() should be true for empty dir")
	}
}

func TestDiscover_Missing(t *testing.T) {
	result, err := Scan("/nonexistent/path/that/does/not/exist")
	if err != nil {
		t.Fatalf("Scan returned error for missing dir: %v", err)
	}

	if !result.IsEmpty() {
		t.Error("IsEmpty() should be true for nonexistent dir")
	}
}

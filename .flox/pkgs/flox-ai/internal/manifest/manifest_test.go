package manifest

import (
	"os"
	"path/filepath"
	"testing"
)

const lockSample = `{
  "lockfile-version": 1,
  "manifest": {
    "install": {
      "claude-code": {"pkg-path": "flox/claude-code"},
      "claude-code-plugin-caveman": {"pkg-path": "flox/claude-code-plugin-caveman"}
    }
  },
  "packages": [
    {"install_id": "claude-code", "attr_path": "claude-code"},
    {"install_id": "claude-code-plugin-caveman", "attr_path": "x"}
  ]
}`

func writeLock(t *testing.T, dir, content string) {
	t.Helper()
	envDir := filepath.Join(dir, ".flox", "env")
	if err := os.MkdirAll(envDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(envDir, "manifest.lock"),
		[]byte(content), 0644); err != nil {
		t.Fatal(err)
	}
}

func TestInstalledReadsIds(t *testing.T) {
	dir := t.TempDir()
	writeLock(t, dir, lockSample)
	got, err := Installed(dir)
	if err != nil {
		t.Fatal(err)
	}
	if !got["claude-code"] || !got["claude-code-plugin-caveman"] {
		t.Fatalf("missing ids: %v", got)
	}
}

func TestInstalledMissingLockIsEmpty(t *testing.T) {
	got, err := Installed(t.TempDir())
	if err != nil {
		t.Fatalf("missing lock should not error: %v", err)
	}
	if len(got) != 0 {
		t.Fatalf("want empty, got %v", got)
	}
}

package plugins

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func setupTestPlugin(t *testing.T) (pluginDir, configDir string) {
	t.Helper()
	base := t.TempDir()

	pluginDir = filepath.Join(base, "share", "claude", "plugins", "test-plugin")
	os.MkdirAll(pluginDir, 0755)
	os.WriteFile(filepath.Join(pluginDir, ".lsp.json"), []byte(`{}`), 0644)
	os.WriteFile(filepath.Join(pluginDir, "installed_plugins.json"),
		[]byte(`{"test-plugin@flox":[{"installPath":"`+pluginDir+`","scope":"project","version":"1.0.0","gitCommitSha":"abc123","installedAt":"2026-01-01T00:00:00Z","lastUpdated":"2026-01-01T00:00:00Z"}]}`), 0644)
	os.WriteFile(filepath.Join(pluginDir, "known_marketplaces.json"),
		[]byte(`{"flox":{"installLocation":"/flox","lastUpdated":"2026-01-01T00:00:00Z"}}`), 0644)

	configDir = filepath.Join(base, "config")
	os.MkdirAll(filepath.Join(configDir, "plugins"), 0755)

	return pluginDir, configDir
}

func TestAdd(t *testing.T) {
	pluginDir, configDir := setupTestPlugin(t)
	_, err := Add(pluginDir, configDir)
	if err != nil {
		t.Fatalf("Add failed: %v", err)
	}

	link := filepath.Join(configDir, "plugins", "test-plugin")
	target, err := os.Readlink(link)
	if err != nil {
		t.Fatalf("symlink not created: %v", err)
	}
	// target should be relative
	if filepath.IsAbs(target) {
		t.Errorf("symlink should be relative, got absolute: %s", target)
	}
	// resolved target should point to pluginDir
	resolved := filepath.Join(configDir, "plugins", target)
	resolved = filepath.Clean(resolved)
	if resolved != pluginDir {
		t.Errorf("resolved symlink: want %s, got %s", pluginDir, resolved)
	}

	ipPath := filepath.Join(configDir, "plugins", "installed_plugins.json")
	ip, err := ReadJSONMap(ipPath)
	if err != nil {
		t.Fatalf("read installed_plugins.json: %v", err)
	}
	entries, ok := ip["test-plugin@flox"].([]interface{})
	if !ok || len(entries) == 0 {
		t.Fatal("missing test-plugin@flox")
	}
	entry := entries[0].(map[string]interface{})
	if entry["installedAt"] == "2026-01-01T00:00:00Z" {
		t.Error("installedAt should be patched to current time, got source placeholder")
	}
	if entry["lastUpdated"] == "2026-01-01T00:00:00Z" {
		t.Error("lastUpdated should be patched to current time, got source placeholder")
	}
	if _, err := time.Parse(timestampFormat, entry["installedAt"].(string)); err != nil {
		t.Errorf("installedAt not in expected format: %v", err)
	}
	if _, err := time.Parse(timestampFormat, entry["lastUpdated"].(string)); err != nil {
		t.Errorf("lastUpdated not in expected format: %v", err)
	}

	kmPath := filepath.Join(configDir, "plugins", "known_marketplaces.json")
	km, err := ReadJSONMap(kmPath)
	if err != nil {
		t.Fatalf("read known_marketplaces.json: %v", err)
	}
	if _, ok := km["flox"]; !ok {
		t.Error("missing flox marketplace")
	}
}

func TestRemove(t *testing.T) {
	pluginDir, configDir := setupTestPlugin(t)
	Add(pluginDir, configDir)
	err := Remove("test-plugin", configDir)
	if err != nil {
		t.Fatalf("Remove failed: %v", err)
	}
	link := filepath.Join(configDir, "plugins", "test-plugin")
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Error("symlink should be removed")
	}
	ipPath := filepath.Join(configDir, "plugins", "installed_plugins.json")
	if _, err := os.Stat(ipPath); !os.IsNotExist(err) {
		t.Error("installed_plugins.json should be removed when empty")
	}
}

func TestList(t *testing.T) {
	pluginDir, configDir := setupTestPlugin(t)
	Add(pluginDir, configDir)
	entries, err := List(configDir)
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}
	if len(entries) != 1 {
		t.Fatalf("want 1 entry, got %d", len(entries))
	}
	if entries[0].Name != "test-plugin" {
		t.Errorf("want test-plugin, got %s", entries[0].Name)
	}
	if !entries[0].IsSymlink {
		t.Error("should be a symlink")
	}
	if entries[0].Broken {
		t.Error("should not be broken")
	}
}

func TestClean(t *testing.T) {
	pluginDir, configDir := setupTestPlugin(t)
	shareDir := filepath.Dir(filepath.Dir(pluginDir)) // base/share/claude-code

	Add(pluginDir, configDir)
	err := Clean(configDir, shareDir)
	if err != nil {
		t.Fatalf("Clean failed: %v", err)
	}
	link := filepath.Join(configDir, "plugins", "test-plugin")
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Error("managed symlink should be removed")
	}
}

func TestClean_PreservesUserPlugins(t *testing.T) {
	_, configDir := setupTestPlugin(t)
	pluginsDir := filepath.Join(configDir, "plugins")
	os.MkdirAll(pluginsDir, 0755)
	userDir := t.TempDir()
	os.Symlink(userDir, filepath.Join(pluginsDir, "user-plugin"))

	Clean(configDir, "/nonexistent/share/claude-code")

	link := filepath.Join(pluginsDir, "user-plugin")
	if _, err := os.Lstat(link); err != nil {
		t.Error("user symlink should be preserved")
	}
}

func TestAdd_Idempotent(t *testing.T) {
	pluginDir, configDir := setupTestPlugin(t)
	Add(pluginDir, configDir)
	_, err := Add(pluginDir, configDir)
	if err != nil {
		t.Fatalf("second Add failed: %v", err)
	}
	ipPath := filepath.Join(configDir, "plugins", "installed_plugins.json")
	data, _ := os.ReadFile(ipPath)
	count := strings.Count(string(data), "test-plugin@flox")
	if count != 1 {
		t.Errorf("key should appear once, found %d times", count)
	}
}

func TestAdd_PreservesInstalledAt(t *testing.T) {
	pluginDir, configDir := setupTestPlugin(t)

	origNow := now
	t.Cleanup(func() { now = origNow })
	now = func() string { return "2030-06-01T00:00:00.000Z" }

	if _, err := Add(pluginDir, configDir); err != nil {
		t.Fatalf("first Add failed: %v", err)
	}

	now = func() string { return "2030-06-02T00:00:00.000Z" }
	if _, err := Add(pluginDir, configDir); err != nil {
		t.Fatalf("second Add failed: %v", err)
	}

	ipPath := filepath.Join(configDir, "plugins", "installed_plugins.json")
	ip, err := ReadJSONMap(ipPath)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	entries := ip["test-plugin@flox"].([]interface{})
	entry := entries[0].(map[string]interface{})
	if entry["installedAt"] != "2030-06-01T00:00:00.000Z" {
		t.Errorf("installedAt should be preserved from first Add, got %v", entry["installedAt"])
	}
	if entry["lastUpdated"] != "2030-06-02T00:00:00.000Z" {
		t.Errorf("lastUpdated should reflect second Add, got %v", entry["lastUpdated"])
	}
}

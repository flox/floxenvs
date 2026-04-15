package plugins

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
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
	if _, ok := ip["test-plugin@flox"]; !ok {
		t.Error("missing test-plugin@flox")
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
	shareDir := filepath.Dir(filepath.Dir(pluginDir)) // base/share/claude

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

	Clean(configDir, "/nonexistent/share/claude")

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

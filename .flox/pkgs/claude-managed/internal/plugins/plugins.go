package plugins

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"flox.dev/claude-managed/internal/symlinks"
)

// timestampFormat matches Claude Code's installed_plugins.json schema
// (ISO 8601 with millisecond precision, UTC).
const timestampFormat = "2006-01-02T15:04:05.000Z"

// now is overridable in tests.
var now = func() string { return time.Now().UTC().Format(timestampFormat) }

// Add symlinks a plugin into the config dir and merges
// its JSON config files. Returns a list of warnings
// (e.g., missing JSON files) via the second return value.
func Add(pluginDir, configDir string) ([]string, error) {
	name := filepath.Base(pluginDir)
	pluginsDir := filepath.Join(configDir, "plugins")
	if err := os.MkdirAll(pluginsDir, 0755); err != nil {
		return nil, err
	}

	if err := symlinks.Add(pluginDir, pluginsDir); err != nil {
		return nil, err
	}

	link := filepath.Join(pluginsDir, name)
	var warnings []string

	// merge installed_plugins.json, patching installPath and timestamps
	ipPath := filepath.Join(pluginDir, "installed_plugins.json")
	ipSource, _ := ReadJSONMap(ipPath)
	if ipSource != nil {
		ipTarget := filepath.Join(pluginsDir, "installed_plugins.json")
		existing, _ := ReadJSONMap(ipTarget)
		patchEntries(ipSource, link, existing)
		if err := MergeJSONFile(ipTarget, ipSource); err != nil {
			return warnings, fmt.Errorf("merge installed_plugins.json: %w", err)
		}
	} else {
		warnings = append(warnings,
			fmt.Sprintf("%s: missing installed_plugins.json (plugin won't be trusted by Claude Code)", name))
	}

	// merge known_marketplaces.json
	kmPath := filepath.Join(pluginDir, "known_marketplaces.json")
	kmSource, _ := ReadJSONMap(kmPath)
	if kmSource != nil {
		kmTarget := filepath.Join(pluginsDir, "known_marketplaces.json")
		if err := MergeJSONFile(kmTarget, kmSource); err != nil {
			return warnings, fmt.Errorf("merge known_marketplaces.json: %w", err)
		}
	}

	return warnings, nil
}

// Remove deletes a plugin symlink and regenerates JSON config files.
func Remove(name, configDir string) error {
	pluginsDir := filepath.Join(configDir, "plugins")
	if err := symlinks.Remove(name, pluginsDir); err != nil {
		return err
	}
	return regenerateJSON(pluginsDir)
}

// List returns all plugin entries in the config dir.
func List(configDir string) ([]symlinks.Entry, error) {
	return symlinks.List(filepath.Join(configDir, "plugins"))
}

// Clean removes all symlinks in plugins dir whose targets point
// into the share dir, then regenerates JSON from remaining plugins.
func Clean(configDir, shareDir string) error {
	pluginsDir := filepath.Join(configDir, "plugins")
	if _, err := symlinks.Clean(pluginsDir, shareDir); err != nil {
		return err
	}
	return regenerateJSON(pluginsDir)
}

// patchEntries sets installPath, installedAt, and lastUpdated
// on each entry. installedAt is preserved from the existing
// target file when present; otherwise set to current time.
// lastUpdated is always refreshed.
// Supports both v1 (flat) and v2 (wrapped in "plugins" key) formats.
func patchEntries(ip map[string]interface{}, pluginPath string, existing map[string]interface{}) {
	ts := now()
	target := entriesMap(ip)
	prev := entriesMap(existing)
	for key, v := range target {
		arr, ok := v.([]interface{})
		if !ok {
			continue
		}
		prevInstalledAt := lookupInstalledAt(prev, key)
		for _, item := range arr {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			m["installPath"] = pluginPath
			if prevInstalledAt != "" {
				m["installedAt"] = prevInstalledAt
			} else {
				m["installedAt"] = ts
			}
			m["lastUpdated"] = ts
		}
	}
}

// entriesMap returns the map containing plugin entries, unwrapping
// the v2 "plugins" key if present. Returns nil for nil input.
func entriesMap(m map[string]interface{}) map[string]interface{} {
	if m == nil {
		return nil
	}
	if plugins, ok := m["plugins"].(map[string]interface{}); ok {
		return plugins
	}
	return m
}

// lookupInstalledAt returns the first entry's installedAt for key,
// or "" if not present.
func lookupInstalledAt(m map[string]interface{}, key string) string {
	if m == nil {
		return ""
	}
	arr, ok := m[key].([]interface{})
	if !ok || len(arr) == 0 {
		return ""
	}
	entry, ok := arr[0].(map[string]interface{})
	if !ok {
		return ""
	}
	s, _ := entry["installedAt"].(string)
	return s
}

// regenerateJSON rebuilds installed_plugins.json and known_marketplaces.json
// from all remaining symlinked plugin directories.
func regenerateJSON(pluginsDir string) error {
	entries, err := os.ReadDir(pluginsDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	mergedIP := make(map[string]interface{})
	mergedKM := make(map[string]interface{})

	// Preserve installedAt timestamps from the existing merged file.
	existingIP, _ := ReadJSONMap(filepath.Join(pluginsDir, "installed_plugins.json"))

	for _, e := range entries {
		path := filepath.Join(pluginsDir, e.Name())
		info, err := os.Lstat(path)
		if err != nil || info.Mode()&os.ModeSymlink == 0 {
			continue
		}
		target, err := os.Readlink(path)
		if err != nil {
			continue
		}

		ip, _ := ReadJSONMap(filepath.Join(target, "installed_plugins.json"))
		if ip != nil {
			patchEntries(ip, path, existingIP)
		}
		for k, v := range ip {
			mergedIP[k] = v
		}

		km, _ := ReadJSONMap(filepath.Join(target, "known_marketplaces.json"))
		for k, v := range km {
			mergedKM[k] = v
		}
	}

	ipPath := filepath.Join(pluginsDir, "installed_plugins.json")
	kmPath := filepath.Join(pluginsDir, "known_marketplaces.json")

	if len(mergedIP) == 0 {
		os.Remove(ipPath)
	} else {
		if err := WriteJSON(ipPath, mergedIP); err != nil {
			return err
		}
	}

	if len(mergedKM) == 0 {
		os.Remove(kmPath)
	} else {
		if err := WriteJSON(kmPath, mergedKM); err != nil {
			return err
		}
	}

	return nil
}

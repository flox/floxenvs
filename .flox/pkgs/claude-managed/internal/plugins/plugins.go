package plugins

import (
	"fmt"
	"os"
	"path/filepath"

	"flox.dev/claude-managed/internal/symlinks"
)

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

	// merge installed_plugins.json, patching installPath
	ipPath := filepath.Join(pluginDir, "installed_plugins.json")
	ipSource, _ := ReadJSONMap(ipPath)
	if ipSource != nil {
		patchInstallPaths(ipSource, link)
		ipTarget := filepath.Join(pluginsDir, "installed_plugins.json")
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
	} else {
		warnings = append(warnings,
			fmt.Sprintf("%s: missing known_marketplaces.json (marketplace won't be registered)", name))
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

// patchInstallPaths sets installPath in each entry array
// to the actual plugin location in the config dir.
func patchInstallPaths(ip map[string]interface{}, pluginPath string) {
	for _, v := range ip {
		arr, ok := v.([]interface{})
		if !ok {
			continue
		}
		for _, item := range arr {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			m["installPath"] = pluginPath
		}
	}
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
			patchInstallPaths(ip, path)
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

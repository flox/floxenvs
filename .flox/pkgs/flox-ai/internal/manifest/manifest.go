// Package manifest reads the active Flox environment's manifest.lock to
// determine which packages are installed.
package manifest

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type lockFile struct {
	Manifest struct {
		Install map[string]json.RawMessage `json:"install"`
	} `json:"manifest"`
	Packages []struct {
		InstallID string `json:"install_id"`
	} `json:"packages"`
}

// Installed returns the set of install ids present in
// <projectDir>/.flox/env/manifest.lock. Returns an empty set (no error)
// when the lock file is absent.
func Installed(projectDir string) (map[string]bool, error) {
	path := filepath.Join(projectDir, ".flox", "env", "manifest.lock")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]bool{}, nil
		}
		return nil, err
	}
	var lf lockFile
	if err := json.Unmarshal(data, &lf); err != nil {
		return nil, err
	}
	out := map[string]bool{}
	for id := range lf.Manifest.Install {
		out[id] = true
	}
	for _, p := range lf.Packages {
		if p.InstallID != "" {
			out[p.InstallID] = true
		}
	}
	return out, nil
}

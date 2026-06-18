package tui

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// uiConfig is the persisted user preference set, stored as a small TOML file
// under the active environment's .flox/cache/flox-ai/config.toml.
type uiConfig struct {
	Theme   string // selected tint id
	Preview bool   // detail pane visibility
}

func configPath(projectDir string) string {
	return filepath.Join(projectDir, ".flox", "cache", "flox-ai", "config.toml")
}

// loadConfig reads the UI preferences, returning sensible defaults when the
// file is missing or unreadable.
func loadConfig(projectDir string) uiConfig {
	cfg := uiConfig{Preview: true}
	data, err := os.ReadFile(configPath(projectDir))
	if err != nil {
		return cfg
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.Trim(strings.TrimSpace(v), `"`)
		switch k {
		case "theme":
			cfg.Theme = v
		case "preview":
			cfg.Preview, _ = strconv.ParseBool(v)
		}
	}
	return cfg
}

// saveConfig writes the UI preferences (best-effort).
func saveConfig(projectDir string, cfg uiConfig) error {
	if projectDir == "" {
		return nil
	}
	p := configPath(projectDir)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	var b strings.Builder
	b.WriteString("# flox-ai UI preferences\n")
	fmt.Fprintf(&b, "theme = %q\n", cfg.Theme)
	fmt.Fprintf(&b, "preview = %t\n", cfg.Preview)
	return os.WriteFile(p, []byte(b.String()), 0o644)
}

// persist writes the current UI state to disk (best-effort, ignores errors).
func (m model) persist() {
	id := ""
	if m.tintIdx >= 0 && m.tintIdx < len(m.tintIDs) {
		id = m.tintIDs[m.tintIdx]
	}
	_ = saveConfig(m.projectDir, uiConfig{Theme: id, Preview: m.showDetail})
}

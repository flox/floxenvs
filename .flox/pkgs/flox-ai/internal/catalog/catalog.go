// Package catalog loads and queries the curated flox-ai fragment
// catalog (ai-catalog.json) the TUI presents for search and install.
package catalog

import (
	"encoding/json"
	"strings"
)

// Item is one catalog entry. Mirrors the website data.json schema.
type Item struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Type        string   `json:"type"` // plugin|skill|agent|rule
	For         string   `json:"for"`  // agent this fragment targets, e.g. "claude-code"
	Description string   `json:"description"`
	Tags        []string `json:"tags"`
	Categories  []string `json:"categories"`
	Featured    bool     `json:"featured"`
	Link        string   `json:"link"`
	Homepage    string   `json:"homepage,omitempty"`
	InstallPkg  string   `json:"installPkg"`
	Intro       string   `json:"intro,omitempty"`
	Summary     []string `json:"summary,omitempty"`
	Stack       []string `json:"stack,omitempty"`
	License     string   `json:"license,omitempty"`
	Maintainer  string   `json:"maintainer,omitempty"`
	Audit       *Audit   `json:"audit,omitempty"`
}

// Envelope is the top-level data.json document.
type Envelope struct {
	SchemaVersion int    `json:"schema_version"`
	GeneratedAt   string `json:"generated_at"`
	Commit        string `json:"commit"`
	Items         []Item `json:"items"`
}

// Title returns the display title (Name field of the catalog), falling
// back to the id when empty. (The JSON "name" is the human title.)
func (it Item) Title() string {
	if it.Name != "" {
		return it.Name
	}
	return it.ID
}

// FloxHubURL is where the package is deployed on FloxHub, derived from its
// pkg-path (e.g. flox/foo -> https://hub.flox.dev/flox/foo).
func (it Item) FloxHubURL() string {
	if it.InstallPkg == "" {
		return ""
	}
	return "https://hub.flox.dev/" + it.InstallPkg
}

// Match reports whether the item matches a free-text query (case-
// insensitive substring over name, id, description, and tags). An empty
// query matches everything.
func (it Item) Match(query string) bool {
	q := strings.ToLower(strings.TrimSpace(query))
	if q == "" {
		return true
	}
	hay := strings.ToLower(it.Name + " " + it.ID + " " + it.Description +
		" " + strings.Join(it.Tags, " "))
	return strings.Contains(hay, q)
}

// Parse decodes the data.json envelope into its items.
func Parse(data []byte) ([]Item, error) {
	var env Envelope
	if err := json.Unmarshal(data, &env); err != nil {
		return nil, err
	}
	return env.Items, nil
}

// Filter returns items matching the given type (empty = any) and query
// (empty = any), preserving order.
func Filter(items []Item, typ, query string) []Item {
	out := make([]Item, 0, len(items))
	for _, it := range items {
		if typ != "" && it.Type != typ {
			continue
		}
		if !it.Match(query) {
			continue
		}
		out = append(out, it)
	}
	return out
}

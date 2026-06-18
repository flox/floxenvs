package catalog

import (
	_ "embed"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

//go:embed embedded.json
var embedded []byte

// DefaultURL is the published catalog endpoint.
const DefaultURL = "https://flox.github.io/floxenvs/ai-catalog.json"

// Source records where a loaded catalog came from.
type Source int

const (
	SourceHTTP Source = iota
	SourceCache
	SourceEmbedded
)

func (s Source) String() string {
	switch s {
	case SourceHTTP:
		return "http"
	case SourceCache:
		return "cache"
	default:
		return "embedded"
	}
}

// Config controls Load.
type Config struct {
	URL      string
	CacheDir string
	Timeout  time.Duration
}

// Load resolves the catalog: HTTP first (caching on success), then the
// on-disk cache, then the embedded snapshot. It only errors if all
// three fail to parse.
func Load(cfg Config) ([]Item, Source, error) {
	if data, err := fetch(cfg.URL, cfg.Timeout); err == nil {
		if items, perr := Parse(data); perr == nil {
			writeCache(cfg.CacheDir, data)
			return items, SourceHTTP, nil
		}
	}

	cachePath := filepath.Join(cfg.CacheDir, "catalog.json")
	if data, err := os.ReadFile(cachePath); err == nil {
		if items, perr := Parse(data); perr == nil {
			return items, SourceCache, nil
		}
	}

	items, err := Parse(embedded)
	if err != nil {
		return nil, SourceEmbedded, fmt.Errorf("embedded catalog: %w", err)
	}
	return items, SourceEmbedded, nil
}

func fetch(url string, timeout time.Duration) ([]byte, error) {
	if url == "" {
		return nil, fmt.Errorf("no url")
	}
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

func writeCache(dir string, data []byte) {
	if dir == "" {
		return
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return
	}
	_ = os.WriteFile(filepath.Join(dir, "catalog.json"), data, 0644)
}

// CacheDir returns the default cache directory
// ($XDG_CACHE_HOME/flox-ai or ~/.cache/flox-ai).
func CacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".cache")
	}
	return filepath.Join(base, "flox-ai")
}

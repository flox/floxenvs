package catalog

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadFromHTTP(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte(sample))
		}))
	defer srv.Close()

	cacheDir := t.TempDir()
	items, src, err := Load(Config{
		URL:      srv.URL,
		CacheDir: cacheDir,
		Timeout:  2 * time.Second,
	})
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if src != SourceHTTP {
		t.Errorf("source = %v, want http", src)
	}
	if len(items) != 2 {
		t.Fatalf("got %d items", len(items))
	}
	if _, err := os.Stat(filepath.Join(cacheDir, "catalog.json")); err != nil {
		t.Errorf("cache not written: %v", err)
	}
}

func TestLoadFallsBackToCache(t *testing.T) {
	cacheDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(cacheDir, "catalog.json"),
		[]byte(sample), 0644); err != nil {
		t.Fatal(err)
	}
	items, src, err := Load(Config{
		URL:      "http://127.0.0.1:0/nope",
		CacheDir: cacheDir,
		Timeout:  200 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if src != SourceCache {
		t.Errorf("source = %v, want cache", src)
	}
	if len(items) != 2 {
		t.Fatalf("got %d items", len(items))
	}
}

func TestLoadFallsBackToEmbedded(t *testing.T) {
	items, src, err := Load(Config{
		URL:      "http://127.0.0.1:0/nope",
		CacheDir: t.TempDir(),
		Timeout:  200 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if src != SourceEmbedded {
		t.Errorf("source = %v, want embedded", src)
	}
	if len(items) == 0 {
		t.Error("embedded catalog is empty")
	}
}

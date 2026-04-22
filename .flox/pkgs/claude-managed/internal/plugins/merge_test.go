package plugins

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestMergeJSONFiles_Empty(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "out.json")
	err := MergeJSONFile(target, nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, err := os.Stat(target); !os.IsNotExist(err) {
		t.Error("should not create file for nil input")
	}
}

func TestMergeJSONFile_NewFile(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "out.json")
	source := map[string]interface{}{"foo": "bar"}
	err := MergeJSONFile(target, source)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	data, _ := os.ReadFile(target)
	var result map[string]interface{}
	json.Unmarshal(data, &result)
	if result["foo"] != "bar" {
		t.Errorf("want foo=bar, got %v", result["foo"])
	}
}

func TestMergeJSONFile_MergeExisting(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "out.json")
	os.WriteFile(target, []byte(`{"existing":"value"}`), 0644)
	source := map[string]interface{}{"new": "entry"}
	err := MergeJSONFile(target, source)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	data, _ := os.ReadFile(target)
	var result map[string]interface{}
	json.Unmarshal(data, &result)
	if result["existing"] != "value" {
		t.Errorf("lost existing key")
	}
	if result["new"] != "entry" {
		t.Errorf("missing new key")
	}
}

func TestMergeJSONFile_SourceOverwrites(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "out.json")
	os.WriteFile(target, []byte(`{"key":"old"}`), 0644)
	source := map[string]interface{}{"key": "new"}
	err := MergeJSONFile(target, source)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	data, _ := os.ReadFile(target)
	var result map[string]interface{}
	json.Unmarshal(data, &result)
	if result["key"] != "new" {
		t.Errorf("source should overwrite: got %v", result["key"])
	}
}

func TestReadJSONMap_Missing(t *testing.T) {
	result, err := ReadJSONMap("/nonexistent")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != nil {
		t.Error("should return nil for missing file")
	}
}

func TestReadJSONMap_Valid(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "test.json")
	os.WriteFile(f, []byte(`{"a":"b"}`), 0644)
	result, err := ReadJSONMap(f)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result["a"] != "b" {
		t.Errorf("want a=b, got %v", result["a"])
	}
}

func TestReadJSONMap_Invalid(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "bad.json")
	os.WriteFile(f, []byte(`not json`), 0644)
	_, err := ReadJSONMap(f)
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

package plugins

import (
	"encoding/json"
	"os"
)

// ReadJSONMap reads a JSON file as a map. Returns nil
// (no error) if the file doesn't exist.
func ReadJSONMap(path string) (map[string]interface{}, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var m map[string]interface{}
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return m, nil
}

// MergeJSONFile merges source map keys into the target
// JSON file. Creates the file if it doesn't exist.
// Source keys overwrite existing keys.
// Does nothing if source is nil or empty.
func MergeJSONFile(targetPath string, source map[string]interface{}) error {
	if len(source) == 0 {
		return nil
	}

	existing, err := ReadJSONMap(targetPath)
	if err != nil {
		existing = nil
	}

	merged := make(map[string]interface{})
	for k, v := range existing {
		merged[k] = v
	}
	for k, v := range source {
		merged[k] = v
	}

	data, err := json.MarshalIndent(merged, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(targetPath, append(data, '\n'), 0644)
}

// WriteJSON writes a map as pretty-printed JSON.
func WriteJSON(path string, data map[string]interface{}) error {
	b, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0644)
}

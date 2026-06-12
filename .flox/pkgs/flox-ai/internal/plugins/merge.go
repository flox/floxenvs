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
//
// When both existing[k] and source[k] are maps, their entries
// are combined one level deep. This is required for the v2
// installed_plugins.json schema, where every plugin's file
// wraps its entries under a single top-level "plugins" key:
// without deep-merge each new `plugins add` would clobber the
// inner map and leave only the last plugin registered.
// The v1 (flat) schema is unaffected because its top-level
// values are arrays, not maps.
func MergeJSONFile(targetPath string, source map[string]interface{}) error {
	if len(source) == 0 {
		return nil
	}

	existing, err := ReadJSONMap(targetPath)
	if err != nil {
		existing = nil
	}

	merged := mergeOneLevel(existing, source)

	data, err := json.MarshalIndent(merged, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(targetPath, append(data, '\n'), 0644)
}

// mergeOneLevel returns a new map containing the union of
// existing and source. When both sides hold a map at the same
// key, those maps' entries are combined (source wins on
// conflicts). Otherwise source's value replaces existing's.
// One level of recursion is sufficient for the v2 schema:
// the inner map's values are arrays of entries, which should
// be replaced wholesale on conflict (re-`plugins add` of the
// same plugin name should replace, not append).
func mergeOneLevel(existing, source map[string]interface{}) map[string]interface{} {
	merged := make(map[string]interface{}, len(existing)+len(source))
	for k, v := range existing {
		merged[k] = v
	}
	for k, v := range source {
		if existingMap, ok := merged[k].(map[string]interface{}); ok {
			if sourceMap, ok := v.(map[string]interface{}); ok {
				for ik, iv := range sourceMap {
					existingMap[ik] = iv
				}
				merged[k] = existingMap
				continue
			}
		}
		merged[k] = v
	}
	return merged
}

// WriteJSON writes a map as pretty-printed JSON.
func WriteJSON(path string, data map[string]interface{}) error {
	b, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0644)
}

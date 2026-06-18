// Package findings defines the normalized cross-tool finding.
package findings

import "sort"

type Finding struct {
	Tool     string `json:"tool"`
	Severity string `json:"severity"` // error | warning | info
	Rule     string `json:"rule,omitempty"`
	Message  string `json:"message"`
	File     string `json:"file,omitempty"`
	Line     int    `json:"line,omitempty"`
	Fixable  bool   `json:"fixable,omitempty"`
}

var sevRank = map[string]int{"error": 0, "warning": 1, "info": 2}

// Sort orders by severity (error<warning<info), then tool, then file/line.
func Sort(fs []Finding) {
	sort.SliceStable(fs, func(i, j int) bool {
		if sevRank[fs[i].Severity] != sevRank[fs[j].Severity] {
			return sevRank[fs[i].Severity] < sevRank[fs[j].Severity]
		}
		if fs[i].Tool != fs[j].Tool {
			return fs[i].Tool < fs[j].Tool
		}
		if fs[i].File != fs[j].File {
			return fs[i].File < fs[j].File
		}
		return fs[i].Line < fs[j].Line
	})
}

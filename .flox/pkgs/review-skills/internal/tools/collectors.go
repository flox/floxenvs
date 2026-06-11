package tools

import (
	"encoding/json"
	"strconv"
	"strings"

	"flox.dev/review-skills/internal/findings"
	"flox.dev/review-skills/internal/score"
)

// jsonOK reports whether b parses as JSON. Used for fail-closed checks:
// a tool that crashed and wrote nothing (or garbage) must not be read as
// a clean zero-issue pass.
func jsonOK(b []byte) bool {
	var v any
	return len(b) > 0 && json.Unmarshal(b, &v) == nil
}

// intAt reads a top-level integer key, defaulting to 0 when absent.
func intAt(m map[string]json.RawMessage, key string) int {
	raw, ok := m[key]
	if !ok {
		return 0
	}
	var n int
	_ = json.Unmarshal(raw, &n)
	return n
}

// scoreSkillTools reads the native .score (0-100). Fails closed.
func scoreSkillTools(b []byte) (int, bool) {
	if !jsonOK(b) {
		return 0, false
	}
	var v struct {
		Score *int `json:"score"`
	}
	if json.Unmarshal(b, &v) != nil || v.Score == nil {
		return 0, false
	}
	return *v.Score, true
}

// scoreErrWarn reads two top-level integer count keys and normalizes via
// NormalizeErrWarn. Fails closed on unparseable output.
func scoreErrWarn(b []byte, errKey, warnKey string) (int, bool) {
	if !jsonOK(b) {
		return 0, false
	}
	var m map[string]json.RawMessage
	if json.Unmarshal(b, &m) != nil {
		return 0, false
	}
	return score.NormalizeErrWarn(intAt(m, errKey), intAt(m, warnKey)), true
}

// scoreAgnix reads .summary.errors/.warnings. Fails closed.
func scoreAgnix(b []byte) (int, bool) {
	if !jsonOK(b) {
		return 0, false
	}
	var v struct {
		Summary struct {
			Errors   int `json:"errors"`
			Warnings int `json:"warnings"`
		} `json:"summary"`
	}
	if json.Unmarshal(b, &v) != nil {
		return 0, false
	}
	return score.NormalizeErrWarn(v.Summary.Errors, v.Summary.Warnings), true
}

// sevFromLevel maps a tool's level string to error|warning|info.
func sevFromLevel(level string) string {
	switch strings.ToLower(level) {
	case "error":
		return "error"
	case "warning", "warn":
		return "warning"
	default:
		return "info"
	}
}

// collectSkillValidator maps skill-validator's results[] of
// {level, category, message, file}, skipping passing checks.
func collectSkillValidator(b []byte) []findings.Finding {
	var v struct {
		Results []struct {
			Level    string `json:"level"`
			Category string `json:"category"`
			Message  string `json:"message"`
			File     string `json:"file"`
		} `json:"results"`
	}
	if json.Unmarshal(b, &v) != nil {
		return nil
	}
	var out []findings.Finding
	for _, r := range v.Results {
		if strings.EqualFold(r.Level, "pass") {
			continue
		}
		out = append(out, findings.Finding{
			Tool: "skill-validator", Severity: sevFromLevel(r.Level),
			Rule: r.Category, Message: r.Message, File: r.File,
		})
	}
	return out
}

// collectAgnix maps agnix's diagnostics[].
func collectAgnix(b []byte) []findings.Finding {
	var v struct {
		Diagnostics []struct {
			Level   string `json:"level"`
			Rule    string `json:"rule"`
			File    string `json:"file"`
			Line    int    `json:"line"`
			Message string `json:"message"`
		} `json:"diagnostics"`
	}
	if json.Unmarshal(b, &v) != nil {
		return nil
	}
	var out []findings.Finding
	for _, d := range v.Diagnostics {
		out = append(out, findings.Finding{
			Tool: "agnix", Severity: sevFromLevel(d.Level), Rule: d.Rule,
			Message: d.Message, File: d.File, Line: d.Line,
		})
	}
	return out
}

// collectClaudelint walks validators[].errors[]/.warnings[], whose items
// are objects {message, file, ruleId, fix}.
func collectClaudelint(b []byte) []findings.Finding {
	type item struct {
		Message string `json:"message"`
		File    string `json:"file"`
		RuleID  string `json:"ruleId"`
	}
	var v struct {
		Validators []struct {
			Name     string `json:"name"`
			Errors   []item `json:"errors"`
			Warnings []item `json:"warnings"`
		} `json:"validators"`
	}
	if json.Unmarshal(b, &v) != nil {
		return nil
	}
	var out []findings.Finding
	for _, val := range v.Validators {
		for _, e := range val.Errors {
			out = append(out, findings.Finding{
				Tool: "claudelint", Severity: "error", Rule: e.RuleID,
				Message: e.Message, File: e.File,
			})
		}
		for _, w := range val.Warnings {
			out = append(out, findings.Finding{
				Tool: "claudelint", Severity: "warning", Rule: w.RuleID,
				Message: w.Message, File: w.File,
			})
		}
	}
	return out
}

// collectCclint walks results[].errors[]/.warnings[], whose items are
// plain strings (e.g. "model: Invalid enum value...").
func collectCclint(b []byte) []findings.Finding {
	var v struct {
		Results []struct {
			File     string   `json:"file"`
			Errors   []string `json:"errors"`
			Warnings []string `json:"warnings"`
		} `json:"results"`
	}
	if json.Unmarshal(b, &v) != nil {
		return nil
	}
	var out []findings.Finding
	for _, r := range v.Results {
		for _, e := range r.Errors {
			out = append(out, findings.Finding{Tool: "cclint", Severity: "error", Message: e, File: r.File})
		}
		for _, w := range r.Warnings {
			out = append(out, findings.Finding{Tool: "cclint", Severity: "warning", Message: w, File: r.File})
		}
	}
	return out
}

// collectSkillTools maps suggestions[], which are objects
// {message, pointsGain, dimension}, to info findings.
func collectSkillTools(b []byte) []findings.Finding {
	var v struct {
		Suggestions []struct {
			Message   string `json:"message"`
			Dimension string `json:"dimension"`
		} `json:"suggestions"`
	}
	if json.Unmarshal(b, &v) != nil {
		return nil
	}
	var out []findings.Finding
	for _, s := range v.Suggestions {
		out = append(out, findings.Finding{
			Tool: "skill-tools", Severity: "info", Rule: s.Dimension, Message: s.Message,
		})
	}
	return out
}

// secSeverity maps a SARIF security-severity score (CVSS 0.0-10.0, as a
// string) to a score.Severity, using the standard CVSS v3 bands. Parsing
// the float (rather than prefix-matching) is important so 10.0 — the
// maximum severity — does not fall through to none.
func secSeverity(s string) score.Severity {
	f, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil {
		return score.SevNone
	}
	switch {
	case f >= 9.0:
		return score.SevCritical
	case f >= 7.0:
		return score.SevHigh
	case f >= 4.0:
		return score.SevMedium
	case f > 0.0:
		return score.SevLow
	default:
		return score.SevNone
	}
}

type sarifDoc struct {
	Runs []struct {
		Tool struct {
			Driver struct {
				Rules []struct {
					ID         string `json:"id"`
					Properties struct {
						SecSeverity string `json:"security-severity"`
					} `json:"properties"`
				} `json:"rules"`
			} `json:"driver"`
		} `json:"tool"`
		Results []struct {
			RuleID  string `json:"ruleId"`
			Level   string `json:"level"`
			Message struct {
				Text string `json:"text"`
			} `json:"message"`
			Locations []struct {
				PhysicalLocation struct {
					ArtifactLocation struct {
						URI string `json:"uri"`
					} `json:"artifactLocation"`
					Region struct {
						StartLine int `json:"startLine"`
					} `json:"region"`
				} `json:"physicalLocation"`
			} `json:"locations"`
		} `json:"results"`
	} `json:"runs"`
}

// collectSkillcheck maps SARIF results[] to findings.
func collectSkillcheck(b []byte) []findings.Finding {
	var v sarifDoc
	if json.Unmarshal(b, &v) != nil {
		return nil
	}
	var out []findings.Finding
	for _, r := range v.Runs {
		for _, res := range r.Results {
			f := findings.Finding{
				Tool: "skillcheck", Severity: sevFromLevel(res.Level),
				Rule: res.RuleID, Message: res.Message.Text,
			}
			if len(res.Locations) > 0 {
				f.File = res.Locations[0].PhysicalLocation.ArtifactLocation.URI
				f.Line = res.Locations[0].PhysicalLocation.Region.StartLine
			}
			out = append(out, f)
		}
	}
	return out
}

// SkillcheckSeverity returns the highest security severity across a SARIF
// document, joining each result's ruleId to its rule's security-severity.
func SkillcheckSeverity(b []byte) score.Severity {
	var v sarifDoc
	if json.Unmarshal(b, &v) != nil {
		return score.SevNone
	}
	rank := map[score.Severity]int{
		score.SevNone: 0, score.SevLow: 1, score.SevMedium: 2,
		score.SevHigh: 3, score.SevCritical: 4,
	}
	worst := score.SevNone
	for _, r := range v.Runs {
		sevByRule := map[string]score.Severity{}
		for _, rule := range r.Tool.Driver.Rules {
			sevByRule[rule.ID] = secSeverity(rule.Properties.SecSeverity)
		}
		for _, res := range r.Results {
			sev, ok := sevByRule[res.RuleID]
			if !ok {
				// Fall back to the result level when the rule has no
				// security-severity property.
				switch sevFromLevel(res.Level) {
				case "error":
					sev = score.SevHigh
				case "warning":
					sev = score.SevMedium
				default:
					sev = score.SevLow
				}
			}
			if rank[sev] > rank[worst] {
				worst = sev
			}
		}
	}
	return worst
}

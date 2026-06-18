// Package score holds the ported review-skills scoring math.
package score

import "math"

// Severity ranks security findings.
type Severity string

const (
	SevNone     Severity = "none"
	SevLow      Severity = "LOW"
	SevMedium   Severity = "MEDIUM"
	SevHigh     Severity = "HIGH"
	SevCritical Severity = "CRITICAL"
)

// Weighted is one ensemble member: a percentage weight and a 0-100 score.
type Weighted struct {
	Weight int
	Score  int
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// NormalizeErrWarn = clamp(100 - 25*err - 5*warn, 0, 100).
func NormalizeErrWarn(err, warn int) int {
	return clamp(100-25*err-5*warn, 0, 100)
}

// Ensemble is the weighted mean of members, rounded. Dividing by the sum
// of the provided weights re-normalizes automatically when a tool is
// dropped. Returns 0 for an empty set.
func Ensemble(ms []Weighted) int {
	sumW, sumWS := 0, 0
	for _, m := range ms {
		sumW += m.Weight
		sumWS += m.Weight * m.Score
	}
	if sumW == 0 {
		return 0
	}
	return int(math.Round(float64(sumWS) / float64(sumW)))
}

// Fuse = round(.35q + .35r + .20s + .10i).
func Fuse(q, r, s, i int) int {
	return int(math.Round(0.35*float64(q) + 0.35*float64(r) + 0.20*float64(s) + 0.10*float64(i)))
}

// ApplyCap lowers the score to the security cap for the severity.
func ApplyCap(score int, sev Severity) int {
	cap := 100
	switch sev {
	case SevCritical:
		cap = 50
	case SevHigh:
		cap = 75
	}
	if score > cap {
		return cap
	}
	return score
}

// Pill maps a score to stable/warn/risk.
func Pill(s int) string {
	switch {
	case s >= 80:
		return "stable"
	case s >= 60:
		return "warn"
	default:
		return "risk"
	}
}

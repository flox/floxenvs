package catalog

// Audit mirrors the website MetricsSchema (the normalized metrics.json).
// It is the per-item audit embedded in data.json.
type Audit struct {
	Overall int    `json:"overall"`
	Status  string `json:"status"` // stable|warn|risk|missing
	Quality struct {
		Score  int `json:"score"`
		Checks []struct {
			ID     string `json:"id"`
			Pass   bool   `json:"pass"`
			Weight int    `json:"weight"`
			Note   string `json:"note"`
		} `json:"checks"`
	} `json:"quality"`
	Reliability struct {
		Score             int     `json:"score"`
		CIGreenStreakDays int     `json:"ci_green_streak_days"`
		LastTestAt        string  `json:"last_test_at"`
		LockfileFresh     bool    `json:"lockfile_fresh"`
		TestDurationS     float64 `json:"test_duration_s"`
		Note              string  `json:"note"`
	} `json:"reliability"`
	Security struct {
		Score    int `json:"score"`
		Cap      int `json:"cap"`
		Scanners []struct {
			Tool   string `json:"tool"`
			Level  string `json:"level"`
			Status string `json:"status"`
		} `json:"scanners"`
		Findings []struct {
			Tool   string `json:"tool"`
			Level  string `json:"level"`
			Count  int    `json:"count"`
			Status string `json:"status"`
			Note   string `json:"note"`
		} `json:"findings"`
	} `json:"security"`
	Impact struct {
		Pass  int  `json:"pass"`
		Total int  `json:"total"`
		Score *int `json:"score"`
	} `json:"impact"`
}

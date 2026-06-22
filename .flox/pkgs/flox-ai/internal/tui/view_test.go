package tui

import (
	"strings"
	"testing"

	"flox.dev/flox-ai/internal/catalog"
)

func TestViewStartScreenTopPicks(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 100, 30
	out := m.View().Content
	if !strings.Contains(out, "search…") {
		t.Error("empty search placeholder must render")
	}
	if !strings.Contains(out, "TOP PICKS") {
		t.Error("start screen must show top picks")
	}
	if !strings.Contains(out, "popular") {
		t.Error("start screen must show popular tags")
	}
}

func TestViewHeader(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 100, 30
	out := m.View().Content
	if !strings.Contains(out, "flox") {
		t.Error("header must show the flox wordmark")
	}
	if !strings.Contains(out, "Claude") {
		t.Error("header must show the agent selector (package title)")
	}
	if !strings.Contains(out, "Switch agent") {
		t.Error("header must show the [a] Switch agent affordance")
	}
}

func TestViewShowsResultsAfterQuery(t *testing.T) {
	m := newTestModel(map[string]bool{"skills-graphify": true})
	m.width, m.height = 100, 30
	m.query = "graph"
	m.mode = modeNormal
	out := m.View().Content
	if !strings.Contains(out, "Graphify") {
		t.Error("result row must show the title")
	}
}

func TestViewMatchCount(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 100, 30
	m.query = "skill"
	out := m.View().Content
	if !strings.Contains(out, "matches") {
		t.Error("count line must render")
	}
}

func TestViewDetailPane(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 120, 30
	m.query = "cave"
	m.mode = modeNormal
	m.cursor = 0
	m.syncDetail()
	out := m.View().Content
	if !strings.Contains(out, "Caveman") || !strings.Contains(out, "Scores") {
		t.Errorf("detail pane must show title and scores; got:\n%s", out)
	}
}

func TestViewNarrowHidesDetail(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 40, 30
	m.query = "skill"
	m.mode = modeNormal
	out := m.View().Content
	if !strings.Contains(out, "Graphify") && !strings.Contains(out, "Foo") {
		t.Error("narrow layout must still render matching results")
	}
}

func TestViewFooterInstallCTA(t *testing.T) {
	m := newTestModel(nil) // nothing installed -> selected is installable
	m.width, m.height = 100, 30
	m.query = "cave"
	m.mode = modeNormal
	m.cursor = 0
	out := m.View().Content
	if !strings.Contains(out, "install") {
		t.Error("footer must surface the install call-to-action")
	}
}

func TestViewFooterUninstallCTA(t *testing.T) {
	m := newTestModel(map[string]bool{"skills-caveman": true})
	m.width, m.height = 100, 30
	m.query = "cave"
	m.mode = modeNormal
	m.cursor = 0
	out := m.View().Content
	if !strings.Contains(out, "uninstall") {
		t.Error("installed selection must offer uninstall")
	}
}

func TestViewWideShowsDivider(t *testing.T) {
	m := newTestModel(nil)
	m.width, m.height = 120, 30
	m.query = "graph"
	m.mode = modeNormal
	m.cursor = 0
	m.syncDetail()
	out := m.View().Content
	if !strings.Contains(out, ruleV) {
		t.Error("wide layout must render the detail divider")
	}
}

func TestAuditScoreBadgeContainsScore(t *testing.T) {
	m := newTestModel(nil)
	badge := m.auditScoreBadge(89, "stable")
	if !strings.Contains(badge, "89") {
		t.Errorf("audit score badge must contain the score; got %q", badge)
	}
	if !strings.Contains(badge, "●") {
		t.Errorf("audit score badge must contain the status dot; got %q", badge)
	}
}

func TestRowLinesWithAuditContainsScore(t *testing.T) {
	m := newTestModel(nil)
	a := &catalog.Audit{}
	a.Overall = 89
	a.Status = "stable"
	it := catalogItem{
		ID: "test-pkg", Name: "TestPkg", Type: "skill",
		For: "claude-code", InstallPkg: "flox/test-pkg",
		Audit: a,
	}
	lines := m.rowLines(it, 80, false)
	head := lines[0]
	if !strings.Contains(head, "89") {
		t.Errorf("row head with audit must contain score 89; got %q", head)
	}
}

func TestRowLinesWithoutAuditHasNoScore(t *testing.T) {
	m := newTestModel(nil)
	it := catalogItem{
		ID: "test-pkg-no-audit", Name: "TestPkgNoAudit", Type: "skill",
		For: "claude-code", InstallPkg: "flox/test-pkg-no-audit",
		Audit: nil,
	}
	lines := m.rowLines(it, 80, false)
	head := lines[0]
	// No audit → no score number should appear in the head line
	// (it's possible scores appear elsewhere, but this item has no audit at all)
	if strings.Contains(head, "●") {
		t.Errorf("row without audit must not contain score dot; got %q", head)
	}
}

func auditDetailModel(a *catalog.Audit) model {
	it := catalogItem{
		ID: "test-detail", Name: "DetailPkg", Type: "skill",
		For: "claude-code", InstallPkg: "flox/test-detail",
		Audit: a,
	}
	items := append(testItems(), it)
	m := newModel(items, nil, []string{"claude"}, nil, nil, nil, nil, "s", "c", "p")
	m.width, m.height = 100, 40
	m.query = "detail"
	m.mode = modeNormal
	m.cursor = 0
	m.modal = modalState{kind: modalAuditDetail, title: "audit detail"}
	return m
}

func TestAuditDetailModalWithAudit(t *testing.T) {
	score := 72
	a := &catalog.Audit{}
	a.Overall = 87
	a.Status = "stable"
	a.Quality.Score = 90
	a.Quality.Checks = []struct {
		ID     string `json:"id"`
		Pass   bool   `json:"pass"`
		Weight int    `json:"weight"`
		Note   string `json:"note"`
	}{
		{ID: "skill-readme", Pass: false, Weight: 10, Note: "missing README"},
	}
	a.Reliability.Score = 80
	a.Security.Score = 75
	a.Security.Scanners = []struct {
		Tool   string `json:"tool"`
		Level  string `json:"level"`
		Status string `json:"status"`
	}{
		{Tool: "trivy", Level: "critical", Status: "pass"},
	}
	a.Security.Findings = []struct {
		Tool   string `json:"tool"`
		Level  string `json:"level"`
		Count  int    `json:"count"`
		Status string `json:"status"`
		Note   string `json:"note"`
	}{
		{Tool: "semgrep", Level: "warning", Count: 2, Status: "warn",
			Note: "hardcoded secret pattern"},
	}
	a.Impact.Pass = 3
	a.Impact.Total = 5
	a.Impact.Score = &score

	m := auditDetailModel(a)
	out := m.viewAuditDetailModal()

	if !strings.Contains(out, "87") {
		t.Errorf("audit detail must contain overall score 87; got:\n%s", out)
	}
	if !strings.Contains(out, "hardcoded secret pattern") {
		t.Errorf("audit detail must contain finding note; got:\n%s", out)
	}
	if !strings.Contains(out, "missing README") {
		t.Errorf("audit detail must contain failed quality check note; got:\n%s", out)
	}
	if !strings.Contains(out, "trivy") {
		t.Errorf("audit detail must contain scanner name; got:\n%s", out)
	}
}

func TestAuditDetailModalNoAudit(t *testing.T) {
	m := auditDetailModel(nil)
	out := m.viewAuditDetailModal()

	if !strings.Contains(out, "Not audited yet") {
		t.Errorf("nil audit must show 'not audited yet' message; got:\n%s", out)
	}
	if !strings.Contains(out, "R") {
		t.Errorf("nil audit hint must mention R key for live review; got:\n%s", out)
	}
}

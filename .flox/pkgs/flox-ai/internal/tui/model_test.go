package tui

import (
	"strings"
	"testing"

	"flox.dev/flox-ai/internal/catalog"
)

func TestSkillsOnlyFilter(t *testing.T) {
	// Real data.json shape: Name is the DISPLAY name (no prefix), the package
	// lives in InstallPkg ("flox/skills-*"). Filtering on Name would wrongly
	// drop everything — this guards that regression.
	in := []catalog.Item{
		{Name: "Caveman", InstallPkg: "flox/skills-caveman"},
		{Name: "Agent Browser", InstallPkg: "flox/agent-browser"},
		{Name: "Graphify", InstallPkg: "flox/skills-graphify"},
		{Name: "Ollama", InstallPkg: "flox/ollama"},
	}
	got := SkillsOnly(in)
	if len(got) != 2 {
		t.Fatalf("want 2 skills, got %d: %+v", len(got), got)
	}
	for _, it := range got {
		if !strings.Contains(it.InstallPkg, "/skills-") {
			t.Fatalf("non-skill leaked: %s", it.InstallPkg)
		}
	}
}

func TestFilterByQuery(t *testing.T) {
	items := []catalog.Item{
		{Name: "Caveman", InstallPkg: "flox/skills-caveman",
			Description: "compress prompts", Tags: []string{"ai", "compression"}},
		{Name: "Graphify", InstallPkg: "flox/skills-graphify",
			Description: "knowledge graphs", Tags: []string{"ai", "knowledge"}},
	}
	if got := FilterByQuery(items, "graph"); len(got) != 1 || got[0].Name != "Graphify" {
		t.Fatalf("free-text 'graph': %+v", got)
	}
	if got := FilterByQuery(items, "#compression"); len(got) != 1 || got[0].Name != "Caveman" {
		t.Fatalf("tag '#compression': %+v", got)
	}
	if got := FilterByQuery(items, "#ai graph"); len(got) != 1 || got[0].Name != "Graphify" {
		t.Fatalf("tag+text '#ai graph': %+v", got)
	}
	if got := FilterByQuery(items, ""); len(got) != 2 {
		t.Fatalf("empty query should return all: %d", len(got))
	}
	if got := FilterByQuery(items, "zzz"); len(got) != 0 {
		t.Fatalf("no match should be empty: %+v", got)
	}
}

func testItems() []catalogItem {
	return []catalogItem{
		{ID: "skills-caveman", Name: "skills-caveman", Type: "plugin",
			For: "claude-code", Tags: []string{"compression", "ai"},
			InstallPkg: "flox/skills-caveman"},
		{ID: "skills-graphify", Name: "skills-graphify", Type: "skill",
			For: "claude-code", Tags: []string{"knowledge", "ai"},
			InstallPkg: "flox/skills-graphify"},
		{ID: "skills-foo", Name: "skills-foo", Type: "skill",
			For: "claude-code", Tags: []string{"misc"},
			InstallPkg: "flox/skills-foo"},
		{ID: "other", Name: "other", Type: "plugin",
			For: "codex", InstallPkg: "flox/other"},
	}
}

func newTestModel(installed map[string]bool) model {
	return newModel(testItems(), installed, []string{"claude"},
		nil, nil, nil, nil, "share", "cfg", "proj")
}

func idx(items []catalogItem, id string) int {
	for i, it := range items {
		if it.ID == id {
			return i
		}
	}
	return -1
}

func has(items []catalogItem, id string) bool { return idx(items, id) >= 0 }

func TestTopPicksUntilQuery(t *testing.T) {
	m := newTestModel(nil)
	if !m.isTopPicks() {
		t.Error("must be in top-picks mode before any query")
	}
	if len(m.visibleItems()) == 0 {
		t.Error("top picks must not be empty on the start screen")
	}
	m.query = "cave"
	if m.isTopPicks() {
		t.Error("a query must leave top-picks mode")
	}
	if !has(m.visibleItems(), "skills-caveman") {
		t.Error("query should surface caveman")
	}
}

func TestTopPicksLimited(t *testing.T) {
	m := newTestModel(nil)
	if len(m.topPicks()) > topPicksLimit {
		t.Errorf("top picks must cap at %d", topPicksLimit)
	}
}

func TestResultsTagFilter(t *testing.T) {
	m := newTestModel(nil)
	m.query = "#ai"
	got := m.results()
	if !has(got, "skills-caveman") || !has(got, "skills-graphify") {
		t.Errorf("#ai tag should match caveman+graphify: %v", got)
	}
	if has(got, "skills-foo") {
		t.Error("foo lacks ai tag")
	}
}

func TestParseQuerySplitsTags(t *testing.T) {
	text, tags := parseQuery("cave #ai #CLI")
	if text != "cave" {
		t.Errorf("text = %q, want %q", text, "cave")
	}
	if len(tags) != 2 || tags[0] != "ai" || tags[1] != "cli" {
		t.Errorf("tags = %v, want [ai cli] (lowercased)", tags)
	}
}

func TestResultsFreeTextPlusTag(t *testing.T) {
	m := newTestModel(nil)
	m.query = "graph #ai" // text "graph" + tag ai
	got := m.results()
	if !has(got, "skills-graphify") {
		t.Errorf("graph #ai should match graphify: %v", got)
	}
	if has(got, "skills-caveman") {
		t.Error("caveman has #ai but not the text 'graph'")
	}
}

func TestResultsAgentFilter(t *testing.T) {
	m := newTestModel(nil)
	m.query = "o"
	if has(m.results(), "other") {
		t.Error("codex item hidden under claude agent")
	}
}

func TestPanelShowsInstalledAndStaged(t *testing.T) {
	m := newTestModel(map[string]bool{"skills-graphify": true})
	m.stageInstall("skills-caveman")
	p := m.panelItems()
	if !has(p, "skills-graphify") || !has(p, "skills-caveman") {
		t.Errorf("panel = %v", p)
	}
}

func TestStageInstallAndRemove(t *testing.T) {
	m := newTestModel(map[string]bool{"skills-graphify": true})
	m.stageInstall("skills-foo")
	if m.pending["skills-foo"] != actionInstall {
		t.Fatal("foo should be staged install")
	}
	m.remove("skills-foo") // unstage
	if m.pending["skills-foo"] != 0 {
		t.Fatal("foo should be unstaged")
	}
	m.remove("skills-graphify") // installed -> uninstall
	if m.pending["skills-graphify"] != actionUninstall {
		t.Fatal("graphify should be staged uninstall")
	}
	m.remove("skills-graphify") // unstage uninstall
	if m.pending["skills-graphify"] != 0 {
		t.Fatal("graphify uninstall should be unstaged")
	}
}

func TestStageInstallSkipsInstalled(t *testing.T) {
	m := newTestModel(map[string]bool{"skills-graphify": true})
	m.stageInstall("skills-graphify")
	if m.pending["skills-graphify"] != 0 {
		t.Error("installed item must not be staged for install")
	}
}

func TestPendingOps(t *testing.T) {
	m := newTestModel(map[string]bool{"skills-graphify": true})
	m.pending = map[string]action{
		"skills-caveman":  actionInstall,
		"skills-graphify": actionUninstall,
	}
	ins, uns := m.pendingOps()
	if len(ins) != 1 || ins[0] != "flox/skills-caveman" {
		t.Fatalf("installs %v", ins)
	}
	if len(uns) != 1 || uns[0] != "skills-graphify" {
		t.Fatalf("uninstalls %v", uns)
	}
}

func TestHasAllTags(t *testing.T) {
	it := catalogItem{Tags: []string{"ai", "Compression"}}
	if !hasAllTags(it, nil) {
		t.Error("no tag filter must match")
	}
	if !hasAllTags(it, []string{"ai", "compression"}) {
		t.Error("subset (case-insensitive) must match")
	}
	if hasAllTags(it, []string{"ai", "missing"}) {
		t.Error("must require all tags present")
	}
}

func TestTopPicksSortsByAuditOverall(t *testing.T) {
	auditOf := func(score int) *catalog.Audit {
		a := &catalog.Audit{}
		a.Overall = score
		a.Status = "stable"
		return a
	}
	items := []catalogItem{
		{ID: "skills-a-low", Name: "skills-a-low", Type: "skill", For: "claude-code",
			InstallPkg: "flox/skills-a-low", Audit: auditOf(40)},
		{ID: "skills-b-high", Name: "skills-b-high", Type: "skill", For: "claude-code",
			InstallPkg: "flox/skills-b-high", Audit: auditOf(90)},
		{ID: "skills-c-none", Name: "skills-c-none", Type: "skill", For: "claude-code",
			InstallPkg: "flox/skills-c-none", Audit: nil},
		{ID: "skills-d-mid", Name: "skills-d-mid", Type: "skill", For: "claude-code",
			InstallPkg: "flox/skills-d-mid", Audit: auditOf(70)},
	}
	m := newModel(items, nil, []string{"claude"}, nil, nil, nil, nil, "s", "c", "p")
	picks := m.topPicks()
	// Expected order: b-high(90) > d-mid(70) > a-low(40) > c-none(nil)
	wantOrder := []string{"skills-b-high", "skills-d-mid", "skills-a-low", "skills-c-none"}
	for i, want := range wantOrder {
		if i >= len(picks) {
			t.Fatalf("picks too short: got %d, want at least %d", len(picks), i+1)
		}
		if picks[i].ID != want {
			t.Errorf("picks[%d] = %q, want %q", i, picks[i].ID, want)
		}
	}
}

func TestTopPicksExcludesInstalled(t *testing.T) {
	auditOf := func(score int) *catalog.Audit {
		a := &catalog.Audit{}
		a.Overall = score
		a.Status = "stable"
		return a
	}
	items := []catalogItem{
		{ID: "skills-a", Name: "skills-a", Type: "skill", For: "claude-code",
			InstallPkg: "flox/skills-a", Audit: auditOf(90)},
		{ID: "skills-b", Name: "skills-b", Type: "skill", For: "claude-code",
			InstallPkg: "flox/skills-b", Audit: auditOf(80)},
	}
	// skills-a (the higher score) is installed -> excluded from top picks.
	m := newModel(items, map[string]bool{"skills-a": true},
		[]string{"claude"}, nil, nil, nil, nil, "s", "c", "p")
	picks := m.topPicks()
	if len(picks) != 1 || picks[0].ID != "skills-b" {
		t.Fatalf("installed item must be excluded from top picks; got %+v", picks)
	}
}

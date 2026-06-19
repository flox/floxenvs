package tui

import "testing"

func testItems() []catalogItem {
	return []catalogItem{
		{ID: "skills-caveman", Name: "Caveman", Type: "plugin",
			For: "claude-code", Tags: []string{"compression", "ai"},
			InstallPkg: "flox/skills-caveman"},
		{ID: "skills-graphify", Name: "Graphify", Type: "skill",
			For: "claude-code", Tags: []string{"knowledge", "ai"},
			InstallPkg: "flox/skills-graphify"},
		{ID: "skills-foo", Name: "Foo", Type: "skill",
			For: "claude-code", Tags: []string{"misc"},
			InstallPkg: "flox/skills-foo"},
		{ID: "other", Name: "Other", Type: "plugin",
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
		"skills-caveman": actionInstall,
		"skills-graphify":            actionUninstall,
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

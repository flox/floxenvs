package catalog

import "testing"

const sample = `[
  {"id":"a-plugin","name":"Alpha","type":"plugin",
   "description":"alpha tool","tags":["x","compression"],
   "categories":["ai"],"status":"stable","featured":true,
   "link":"https://e/a","installPkg":"flox/a-plugin"},
  {"id":"b-skill","name":"Bravo","type":"skill",
   "description":"bravo","tags":["y"],"categories":["ai"],
   "status":"beta","featured":false,
   "link":"https://e/b","installPkg":"flox/b-skill"}
]`

func TestParse(t *testing.T) {
	items, err := Parse([]byte(sample))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("want 2 items, got %d", len(items))
	}
	if items[0].InstallPkg != "flox/a-plugin" {
		t.Errorf("installPkg = %q", items[0].InstallPkg)
	}
}

func TestMatch(t *testing.T) {
	items, _ := Parse([]byte(sample))
	if !items[0].Match("alph") {
		t.Error("expected Alpha to match 'alph'")
	}
	if !items[0].Match("compress") {
		t.Error("expected tag match on 'compress'")
	}
	if items[0].Match("zzz") {
		t.Error("did not expect match on 'zzz'")
	}
	if !items[1].Match("") {
		t.Error("empty query should match")
	}
}

func TestFilterByType(t *testing.T) {
	items, _ := Parse([]byte(sample))
	got := Filter(items, "skill", "")
	if len(got) != 1 || got[0].ID != "b-skill" {
		t.Fatalf("type filter wrong: %+v", got)
	}
}

func TestFilterByQuery(t *testing.T) {
	items, _ := Parse([]byte(sample))
	got := Filter(items, "", "bravo")
	if len(got) != 1 || got[0].ID != "b-skill" {
		t.Fatalf("query filter wrong: %+v", got)
	}
}

func TestParseFor(t *testing.T) {
	const withFor = `[{"id":"x","name":"X","type":"skill","for":"claude-code",
	  "description":"d","tags":[],"categories":[],"status":"beta",
	  "featured":false,"link":"","installPkg":"flox/x"}]`
	items, err := Parse([]byte(withFor))
	if err != nil {
		t.Fatal(err)
	}
	if items[0].For != "claude-code" {
		t.Errorf("For = %q, want claude-code", items[0].For)
	}
}

func TestParseEnriched(t *testing.T) {
	const s = `[{"id":"x","name":"X","type":"skill","for":"claude-code",
	  "description":"d","tags":[],"categories":[],"status":"beta",
	  "featured":false,"link":"","installPkg":"flox/x",
	  "intro":"hello","summary":["a","b"],"stack":["go"],
	  "license":"MIT","maintainer":"@rok"}]`
	items, err := Parse([]byte(s))
	if err != nil {
		t.Fatal(err)
	}
	it := items[0]
	if it.Intro != "hello" || it.License != "MIT" || it.Maintainer != "@rok" {
		t.Errorf("scalars wrong: %+v", it)
	}
	if len(it.Summary) != 2 || len(it.Stack) != 1 {
		t.Errorf("slices wrong: %+v", it)
	}
}

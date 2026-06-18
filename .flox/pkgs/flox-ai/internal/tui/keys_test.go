package tui

import "testing"

func TestShortHelpByContext(t *testing.T) {
	k := defaultKeyMap()
	m := newTestModel(nil)

	m.mode = modeSearch
	if len(k.shortHelp(m)) == 0 {
		t.Error("search mode short help must not be empty")
	}

	m.mode = modeNormal
	foundInstall, foundApply := false, false
	for _, b := range k.shortHelp(m) {
		switch b.Help().Key {
		case "i":
			foundInstall = true
		case "A":
			foundApply = true
		}
	}
	if !foundInstall || !foundApply {
		t.Error("normal short help must include install and apply")
	}

	m.modal = modalState{kind: modalStream, title: "apply"}
	if len(k.shortHelp(m)) == 0 {
		t.Error("modal short help must not be empty")
	}
}

func TestFullHelpGroups(t *testing.T) {
	if len(defaultKeyMap().fullHelp(newTestModel(nil))) < 3 {
		t.Error("full help should have several groups")
	}
}

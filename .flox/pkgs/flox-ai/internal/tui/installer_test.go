package tui

import "testing"

func TestFakeInstaller(t *testing.T) {
	var got []string
	var lines []string
	fake := InstallerFunc(func(pkg string, out LineFunc) error {
		got = append(got, pkg)
		out("installing " + pkg)
		return nil
	})
	if err := fake.Install("flox/x", func(s string) { lines = append(lines, s) }); err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0] != "flox/x" {
		t.Fatalf("got %v", got)
	}
	if len(lines) != 1 || lines[0] != "installing flox/x" {
		t.Fatalf("lines %v", lines)
	}
}

func TestFakeUninstaller(t *testing.T) {
	var got []string
	fake := UninstallerFunc(func(id string, out LineFunc) error {
		got = append(got, id)
		return nil
	})
	if err := fake.Uninstall("caveman", func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0] != "caveman" {
		t.Fatalf("got %v", got)
	}
}

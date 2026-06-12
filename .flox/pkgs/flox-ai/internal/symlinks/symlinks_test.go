package symlinks

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAdd(t *testing.T) {
	base := t.TempDir()
	srcFile := filepath.Join(base, "src", "myfile")
	os.MkdirAll(filepath.Dir(srcFile), 0755)
	os.WriteFile(srcFile, []byte("data"), 0644)

	destDir := filepath.Join(base, "dest")

	if err := Add(srcFile, destDir); err != nil {
		t.Fatalf("Add failed: %v", err)
	}

	link := filepath.Join(destDir, "myfile")
	target, err := os.Readlink(link)
	if err != nil {
		t.Fatalf("symlink not created: %v", err)
	}
	if filepath.IsAbs(target) {
		t.Errorf("symlink should be relative, got absolute: %s", target)
	}
	resolved := filepath.Clean(filepath.Join(destDir, target))
	if resolved != srcFile {
		t.Errorf("resolved symlink: want %s, got %s", srcFile, resolved)
	}
}

func TestAdd_Directory(t *testing.T) {
	base := t.TempDir()
	srcDir := filepath.Join(base, "src", "mydir")
	os.MkdirAll(srcDir, 0755)

	destDir := filepath.Join(base, "dest")

	if err := Add(srcDir, destDir); err != nil {
		t.Fatalf("Add directory failed: %v", err)
	}

	link := filepath.Join(destDir, "mydir")
	target, err := os.Readlink(link)
	if err != nil {
		t.Fatalf("symlink not created: %v", err)
	}
	if filepath.IsAbs(target) {
		t.Errorf("symlink should be relative, got absolute: %s", target)
	}
	resolved := filepath.Clean(filepath.Join(destDir, target))
	if resolved != srcDir {
		t.Errorf("resolved symlink: want %s, got %s", srcDir, resolved)
	}
}

func TestAdd_Idempotent(t *testing.T) {
	base := t.TempDir()
	srcFile := filepath.Join(base, "src", "myfile")
	os.MkdirAll(filepath.Dir(srcFile), 0755)
	os.WriteFile(srcFile, []byte("data"), 0644)

	destDir := filepath.Join(base, "dest")

	if err := Add(srcFile, destDir); err != nil {
		t.Fatalf("first Add failed: %v", err)
	}
	if err := Add(srcFile, destDir); err != nil {
		t.Fatalf("second Add failed: %v", err)
	}

	link := filepath.Join(destDir, "myfile")
	if _, err := os.Lstat(link); err != nil {
		t.Fatalf("symlink should exist: %v", err)
	}
}

func TestRemove(t *testing.T) {
	base := t.TempDir()
	srcFile := filepath.Join(base, "src", "myfile")
	os.MkdirAll(filepath.Dir(srcFile), 0755)
	os.WriteFile(srcFile, []byte("data"), 0644)

	destDir := filepath.Join(base, "dest")
	Add(srcFile, destDir)

	if err := Remove("myfile", destDir); err != nil {
		t.Fatalf("Remove failed: %v", err)
	}

	link := filepath.Join(destDir, "myfile")
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Error("symlink should be removed")
	}
}

func TestRemove_NonExistent(t *testing.T) {
	destDir := t.TempDir()
	if err := Remove("nonexistent", destDir); err != nil {
		t.Fatalf("Remove of non-existent should not error: %v", err)
	}
}

func TestList(t *testing.T) {
	base := t.TempDir()
	srcFile := filepath.Join(base, "src", "myfile")
	os.MkdirAll(filepath.Dir(srcFile), 0755)
	os.WriteFile(srcFile, []byte("data"), 0644)

	destDir := filepath.Join(base, "dest")
	Add(srcFile, destDir)

	entries, err := List(destDir)
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}
	if len(entries) != 1 {
		t.Fatalf("want 1 entry, got %d", len(entries))
	}
	e := entries[0]
	if e.Name != "myfile" {
		t.Errorf("want name myfile, got %s", e.Name)
	}
	if !e.IsSymlink {
		t.Error("should be a symlink")
	}
	if e.Broken {
		t.Error("should not be broken")
	}
	if e.Path != filepath.Join(destDir, "myfile") {
		t.Errorf("want path %s, got %s", filepath.Join(destDir, "myfile"), e.Path)
	}
	if e.Target == "" {
		t.Error("target should be set")
	}
}

func TestList_Empty(t *testing.T) {
	destDir := t.TempDir()
	entries, err := List(destDir)
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("want 0 entries, got %d", len(entries))
	}
}

func TestList_NonExistent(t *testing.T) {
	entries, err := List("/nonexistent/path/that/does/not/exist")
	if err != nil {
		t.Fatalf("List on non-existent dir should not error: %v", err)
	}
	if entries != nil {
		t.Errorf("want nil, got %v", entries)
	}
}

func TestList_BrokenSymlink(t *testing.T) {
	base := t.TempDir()
	destDir := filepath.Join(base, "dest")
	os.MkdirAll(destDir, 0755)

	// Create a symlink pointing to a non-existent target
	link := filepath.Join(destDir, "broken")
	os.Symlink("/nonexistent/target", link)

	entries, err := List(destDir)
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}
	if len(entries) != 1 {
		t.Fatalf("want 1 entry, got %d", len(entries))
	}
	if !entries[0].Broken {
		t.Error("entry should be marked as broken")
	}
}

func TestClean(t *testing.T) {
	base := t.TempDir()
	sharePrefix := filepath.Join(base, "share")
	srcFile := filepath.Join(sharePrefix, "myfile")
	os.MkdirAll(sharePrefix, 0755)
	os.WriteFile(srcFile, []byte("data"), 0644)

	destDir := filepath.Join(base, "dest")
	Add(srcFile, destDir)

	removed, err := Clean(destDir, sharePrefix)
	if err != nil {
		t.Fatalf("Clean failed: %v", err)
	}
	if removed != 1 {
		t.Errorf("want 1 removed, got %d", removed)
	}

	link := filepath.Join(destDir, "myfile")
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Error("managed symlink should be removed")
	}
}

func TestClean_PreservesUserSymlinks(t *testing.T) {
	base := t.TempDir()
	userSrc := t.TempDir()
	userFile := filepath.Join(userSrc, "userfile")
	os.WriteFile(userFile, []byte("user"), 0644)

	destDir := filepath.Join(base, "dest")
	os.MkdirAll(destDir, 0755)
	os.Symlink(userFile, filepath.Join(destDir, "userfile"))

	sharePrefix := filepath.Join(base, "share")

	removed, err := Clean(destDir, sharePrefix)
	if err != nil {
		t.Fatalf("Clean failed: %v", err)
	}
	if removed != 0 {
		t.Errorf("want 0 removed, got %d", removed)
	}

	link := filepath.Join(destDir, "userfile")
	if _, err := os.Lstat(link); err != nil {
		t.Error("user symlink should be preserved")
	}
}

func TestClean_NonExistentDir(t *testing.T) {
	removed, err := Clean("/nonexistent/path/that/does/not/exist", "/some/prefix")
	if err != nil {
		t.Fatalf("Clean on non-existent dir should not error: %v", err)
	}
	if removed != 0 {
		t.Errorf("want 0 removed, got %d", removed)
	}
}

func TestClean_SkipsNonSymlinks(t *testing.T) {
	base := t.TempDir()
	sharePrefix := filepath.Join(base, "share")

	destDir := filepath.Join(base, "dest")
	os.MkdirAll(destDir, 0755)

	// Create a regular file (not a symlink) in destDir
	regularFile := filepath.Join(destDir, "regularfile")
	os.WriteFile(regularFile, []byte("data"), 0644)

	removed, err := Clean(destDir, sharePrefix)
	if err != nil {
		t.Fatalf("Clean failed: %v", err)
	}
	if removed != 0 {
		t.Errorf("want 0 removed, got %d", removed)
	}

	if _, err := os.Stat(regularFile); err != nil {
		t.Error("regular file should be preserved")
	}
}

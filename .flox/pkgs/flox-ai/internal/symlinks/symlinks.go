package symlinks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type Entry struct {
	Name      string
	Path      string // symlink path
	Target    string // readlink result
	IsSymlink bool
	Broken    bool
}

func Add(srcPath, destDir string) error {
	name := filepath.Base(srcPath)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return err
	}
	link := filepath.Join(destDir, name)
	relTarget, err := filepath.Rel(destDir, srcPath)
	if err != nil {
		relTarget = srcPath
	}
	os.Remove(link)
	if err := os.Symlink(relTarget, link); err != nil {
		return fmt.Errorf("symlink %s: %w", name, err)
	}
	return nil
}

func Remove(name, destDir string) error {
	link := filepath.Join(destDir, name)
	if err := os.Remove(link); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("remove %s: %w", name, err)
	}
	return nil
}

func List(destDir string) ([]Entry, error) {
	if _, err := os.Stat(destDir); os.IsNotExist(err) {
		return nil, nil
	}
	dirEntries, err := os.ReadDir(destDir)
	if err != nil {
		return nil, err
	}
	var result []Entry
	for _, e := range dirEntries {
		path := filepath.Join(destDir, e.Name())
		info, err := os.Lstat(path)
		if err != nil {
			continue
		}
		if info.Mode()&os.ModeSymlink == 0 {
			continue
		}
		entry := Entry{
			Name:      e.Name(),
			Path:      path,
			IsSymlink: true,
		}
		target, err := os.Readlink(path)
		if err == nil {
			entry.Target = target
			checkPath := target
			if !filepath.IsAbs(target) {
				checkPath = filepath.Join(destDir, target)
			}
			if _, err := os.Stat(checkPath); err != nil {
				entry.Broken = true
			}
		}
		result = append(result, entry)
	}
	return result, nil
}

func Clean(destDir, sharePrefix string) (int, error) {
	if _, err := os.Stat(destDir); os.IsNotExist(err) {
		return 0, nil
	}
	dirEntries, err := os.ReadDir(destDir)
	if err != nil {
		return 0, err
	}
	removed := 0
	for _, e := range dirEntries {
		path := filepath.Join(destDir, e.Name())
		info, err := os.Lstat(path)
		if err != nil || info.Mode()&os.ModeSymlink == 0 {
			continue
		}
		target, err := os.Readlink(path)
		if err != nil {
			continue
		}
		absTarget := target
		if !filepath.IsAbs(target) {
			absTarget = filepath.Join(destDir, target)
		}
		absTarget = filepath.Clean(absTarget)
		if strings.HasPrefix(absTarget, sharePrefix+"/") {
			os.Remove(path)
			removed++
		}
	}
	return removed, nil
}

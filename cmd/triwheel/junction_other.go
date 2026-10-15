//go:build !windows

package main

// Symlinks stand in for junctions when testing off Windows.

import (
	"os"
	"path/filepath"
)

func isLink(p string) bool {
	st, err := os.Lstat(p)
	return err == nil && st.Mode()&os.ModeSymlink != 0
}

func removeLink(p string) error { return os.Remove(p) }

func ensureJunction(link, target string) error {
	target, _ = filepath.Abs(target)
	if cur, err := os.Readlink(link); err == nil {
		if cur == target {
			return nil
		}
		os.Remove(link)
	}
	os.MkdirAll(filepath.Dir(link), 0o755)
	return os.Symlink(target, link)
}

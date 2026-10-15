package main

// Test builds only (devPrefs set): while the game runs, a dev-sync.zip dropped in the VSRGHub folder
// is unpacked over it (theme files) and removed, so changes can be tried without restarting.

import (
	"archive/zip"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func startDevSync(home string) func() {
	if devPrefs == "" {
		return func() {}
	}
	stop := make(chan struct{})
	// (one waiting from before the start goes in first)
	if p := filepath.Join(home, "dev-sync.zip"); fileExists(p) {
		n, err := unpackDev(p, home)
		logf("dev sync: %d files (%v)", n, err)
		os.Remove(p)
	}
	go func() {
		p := filepath.Join(home, "dev-sync.zip")
		for {
			select {
			case <-stop:
				return
			case <-time.After(700 * time.Millisecond):
			}
			st, err := os.Stat(p)
			if err != nil || time.Since(st.ModTime()) < 500*time.Millisecond {
				continue
			}
			n, err := unpackDev(p, home)
			logf("dev sync: %d files (%v)", n, err)
			os.Remove(p)
		}
	}()
	return func() { close(stop) }
}

func unpackDev(zp, home string) (int, error) {
	z, err := zip.OpenReader(zp)
	if err != nil {
		return 0, err
	}
	defer z.Close()
	homeAbs, _ := filepath.Abs(home)
	n := 0
	for _, f := range z.File {
		name := strings.ReplaceAll(f.Name, `\`, "/")
		if strings.HasSuffix(name, "/") {
			continue
		}
		dst := filepath.Join(home, filepath.FromSlash(name))
		if abs, _ := filepath.Abs(dst); !strings.HasPrefix(abs, homeAbs+string(filepath.Separator)) {
			continue
		}
		os.MkdirAll(filepath.Dir(dst), 0o755)
		r, err := f.Open()
		if err != nil {
			continue
		}
		w, err := os.Create(dst)
		if err != nil {
			r.Close()
			continue
		}
		io.Copy(w, r)
		w.Close()
		r.Close()
		n++
	}
	return n, nil
}

func fileExists(p string) bool { _, err := os.Stat(p); return err == nil }

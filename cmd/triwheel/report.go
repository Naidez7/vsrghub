package main

// "Report a problem" (the launcher): one zip with what's needed to see what went wrong, for the
// player to send: what they wrote, VSRG Hub's version and Windows', the launcher's and VSRG Hub's
// logs, and Etterna's latest logs. Nothing is sent from here: the zip lands on the desktop.

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

// buildReport writes the zip into dir and returns its path.
func buildReport(dir, text, etterna, home, data string) (string, error) {
	if dir == "" || !dirExists(dir) {
		if h, err := os.UserHomeDir(); err == nil {
			dir = h
		}
	}
	name := "VSRG Hub report " + time.Now().Format("2006-01-02 15-04-05") + ".zip"
	p := filepath.Join(dir, name)
	f, err := os.Create(p)
	if err != nil {
		return "", err
	}
	defer f.Close()
	z := zip.NewWriter(f)
	defer z.Close()

	var about strings.Builder
	fmt.Fprintf(&about, "What happened:\n%s\n\n", strings.TrimSpace(text))
	fmt.Fprintf(&about, "Launcher: VSRG Hub %s (%s/%s)\n", version, runtime.GOOS, runtime.GOARCH)
	if home != "" {
		fmt.Fprintf(&about, "Installed in Etterna: %s\n", installedVersion(home))
	}
	fmt.Fprintf(&about, "Windows: %s\n", windowsVersion())
	fmt.Fprintf(&about, "Written: %s\n", time.Now().Format(time.RFC1123))
	if w, err := z.Create("about.txt"); err == nil {
		io.WriteString(w, about.String())
	}

	add := func(src, as string) {
		in, err := os.Open(src)
		if err != nil {
			return
		}
		defer in.Close()
		if w, err := z.Create(as); err == nil {
			io.Copy(w, io.LimitReader(in, 20<<20))
		}
	}
	add(filepath.Join(launcherDir(), "launcher.log"), "launcher.log")
	if home != "" {
		add(filepath.Join(home, "vsrghub.log"), "vsrghub.log")
	}
	if data != "" {
		add(filepath.Join(data, "online", "me.txt"), "online/me.txt")
	}
	// Etterna's three latest logs (one per start of the game)
	if etterna != "" {
		logs, _ := filepath.Glob(filepath.Join(etterna, "Logs", "*.log"))
		sort.Slice(logs, func(i, j int) bool { return modTime(logs[i]).After(modTime(logs[j])) })
		for i, l := range logs {
			if i == 3 {
				break
			}
			add(l, "etterna/"+filepath.Base(l))
		}
	}
	return p, nil
}

func modTime(p string) time.Time {
	if fi, err := os.Stat(p); err == nil {
		return fi.ModTime()
	}
	return time.Time{}
}

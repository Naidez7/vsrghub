package main

// Etterna leaves out preferences that Data/Static.ini set when it saves
// Preferences.ini, which would drop the player's own Theme= line. VSRG Hub
// notes the player's theme before Etterna starts and puts it back afterwards.

import (
	"os"
	"path/filepath"
	"strings"
)

func prefsPath(etterna string) string { return filepath.Join(etterna, "Save", "Preferences.ini") }

func readPrefTheme(etterna string) string {
	b, err := os.ReadFile(prefsPath(etterna))
	if err != nil {
		return ""
	}
	for _, l := range strings.Split(string(b), "\n") {
		l = strings.TrimRight(l, "\r")
		if strings.HasPrefix(l, "Theme=") {
			return strings.TrimPrefix(l, "Theme=")
		}
	}
	return ""
}

func restorePrefTheme(etterna, theme string) {
	if theme == "" || isOurTheme(theme) {
		return
	}
	p := prefsPath(etterna)
	b, err := os.ReadFile(p)
	if err != nil {
		return
	}
	text := string(b)
	nl := "\n"
	if strings.Contains(text, "\r\n") {
		nl = "\r\n"
	}
	lines := strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n")
	for i, l := range lines {
		if strings.HasPrefix(l, "Theme=") {
			if l == "Theme="+theme {
				return
			}
			lines[i] = "Theme=" + theme
			os.WriteFile(p, []byte(strings.Join(lines, nl)), 0o644)
			return
		}
	}
	// missing: put it back inside [Options], in alphabetical place
	end := len(lines)
	for i := 1; i < len(lines); i++ {
		if strings.HasPrefix(lines[i], "[") {
			end = i
			break
		}
	}
	at := end
	for i := 1; i < end; i++ {
		if k, _, ok := strings.Cut(lines[i], "="); ok && k > "Theme" {
			at = i
			break
		}
	}
	lines = append(lines[:at], append([]string{"Theme=" + theme}, lines[at:]...)...)
	os.WriteFile(p, []byte(strings.Join(lines, nl)), 0o644)
	logf("restored your Etterna theme (%s) in Preferences.ini", theme)
}

// isOurTheme: one of the launcher's own looks, under its name or the one it had before (TriWheel).
func isOurTheme(theme string) bool {
	return strings.HasPrefix(theme, "VSRG Hub") || strings.HasPrefix(theme, "TriWheel")
}

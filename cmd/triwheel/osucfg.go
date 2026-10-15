package main

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// osuConfig reads the player's osu!.<user>.cfg (the newest one if there are several).
func osuConfig(osuDir string) map[string]string {
	out := map[string]string{}
	matches, _ := filepath.Glob(filepath.Join(osuDir, "osu!.*.cfg"))
	var best string
	var bestT int64
	for _, m := range matches {
		if strings.EqualFold(filepath.Base(m), "osu!.cfg") {
			continue
		}
		if st, err := os.Stat(m); err == nil && st.ModTime().UnixNano() > bestT {
			best, bestT = m, st.ModTime().UnixNano()
		}
	}
	if best == "" {
		return out
	}
	f, err := os.Open(best)
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		k, v, ok := strings.Cut(sc.Text(), "=")
		if ok {
			out[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}
	return out
}

func osuSongDir(osuDir string) string {
	d := osuConfig(osuDir)["BeatmapDirectory"]
	if d == "" {
		d = "Songs"
	}
	if !filepath.IsAbs(d) {
		d = filepath.Join(osuDir, d)
	}
	return d
}

// osuCurrentSkin is the skin selected in osu! ("" when it is osu!'s built-in default).
func osuCurrentSkin(osuDir string) string {
	s := osuConfig(osuDir)["Skin"]
	if s == "" || strings.EqualFold(s, "Default") || strings.EqualFold(s, "User") {
		return ""
	}
	if st, err := os.Stat(filepath.Join(osuDir, "Skins", s)); err != nil || !st.IsDir() {
		return ""
	}
	return s
}

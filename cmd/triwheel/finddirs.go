package main

// Finding the companion games when VSRG Hub is started without their folders.

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func dirExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}

func loadKnownDirs(root string) map[string]string {
	m := map[string]string{}
	if b, err := os.ReadFile(filepath.Join(root, "triwheel-dirs.json")); err == nil {
		json.Unmarshal(b, &m)
	}
	return m
}

func saveKnownDirs(root string, m map[string]string) {
	os.MkdirAll(root, 0o755)
	b, _ := json.MarshalIndent(m, "", "  ")
	os.WriteFile(filepath.Join(root, "triwheel-dirs.json"), b, 0o644)
}

// steamLibraries lists Steam library folders from Steam's libraryfolders.vdf, wherever Steam is.
func steamLibraries() []string {
	var out []string
	seen := map[string]bool{}
	add := func(d string) {
		k := strings.ToLower(filepath.Clean(d))
		if d != "" && !seen[k] && dirExists(d) {
			seen[k] = true
			out = append(out, d)
		}
	}
	steams := append(registrySteamDirs(), `C:\Program Files (x86)\Steam`, `C:\Program Files\Steam`)
	for _, r := range driveRoots() {
		for _, sub := range []string{`Program Files (x86)\Steam`, `Program Files\Steam`, `Steam`, `Games\Steam`} {
			steams = append(steams, filepath.Join(r, sub))
		}
	}
	for _, steam := range steams {
		b, err := os.ReadFile(filepath.Join(steam, "steamapps", "libraryfolders.vdf"))
		if err != nil {
			continue
		}
		add(steam)
		for _, m := range regexp.MustCompile(`"path"\s+"([^"]+)"`).FindAllStringSubmatch(string(b), -1) {
			add(strings.ReplaceAll(m[1], `\\`, `\`))
		}
	}
	// libraries Steam doesn't list (e.g. a drive's SteamLibrary after a reinstall)
	for _, r := range driveRoots() {
		for _, sub := range []string{`SteamLibrary`, `Games\SteamLibrary`, `Steam`} {
			if dirExists(filepath.Join(r, sub, "steamapps")) {
				add(filepath.Join(r, sub))
			}
		}
	}
	return out
}

// isOsuDir: an osu! (stable) install, the folder with osu!.exe.
func isOsuDir(d string) bool {
	st, err := os.Stat(filepath.Join(d, "osu!.exe"))
	return err == nil && !st.IsDir()
}

func findGameDir(id string) string {
	switch id {
	case "osu":
		// osu!'s usual place, then where Windows says osu!.exe is, then the usual folders on every drive
		cands := []string{filepath.Join(os.Getenv("LOCALAPPDATA"), "osu!")}
		cands = append(cands, registryOsuDirs()...)
		for _, r := range driveRoots() {
			for _, sub := range []string{`osu!`, `osu`, `Games\osu!`, `Games\osu`, `Program Files\osu!`, `Program Files (x86)\osu!`} {
				cands = append(cands, filepath.Join(r, sub))
			}
		}
		if h := os.Getenv("USERPROFILE"); h != "" {
			cands = append(cands, filepath.Join(h, "osu!"), filepath.Join(h, "Desktop", "osu!"), filepath.Join(h, "Documents", "osu!"))
		}
		for _, d := range cands {
			if isOsuDir(d) {
				return d
			}
		}
		// (an old setup without osu!.exe beside its Songs: still better than nothing)
		if d := filepath.Join(os.Getenv("LOCALAPPDATA"), "osu!"); dirExists(filepath.Join(d, "Songs")) {
			return d
		}
	case "quaver", "qwilight":
		name := map[string]string{"quaver": "Quaver", "qwilight": "Qwilight"}[id]
		for _, lib := range steamLibraries() {
			if d := filepath.Join(lib, "steamapps", "common", name); dirExists(d) {
				return d
			}
		}
	}
	return ""
}

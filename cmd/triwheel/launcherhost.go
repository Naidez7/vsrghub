package main

// The launcher as a program of its own: vsrghub.exe also runs from anywhere (the desktop, its own
// folder in Programs), not only from Etterna's VSRGHub folder. Run like that it finds Etterna (or is
// told where it is), installs and updates VSRG Hub into Etterna's VSRGHub folder, and starts it.
// Started from Etterna's VSRGHub folder it is that folder's own launcher, as before.

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

//go:embed assets/changelog.json
var changelogJSON []byte

type changeEntry struct {
	Version string `json:"version"`
	Date    string `json:"date"`
	Notes   string `json:"notes"`
}

func builtinChangelog() []changeEntry {
	var out []changeEntry
	json.Unmarshal(changelogJSON, &out)
	return out
}

// defaultFeedURL is where the launcher reads the newest version and the changelog: release/ in the
// public GitHub repository (the "update feed"; the version zips are beside it). update-url.txt beside the program or in Save/VSRGHub replaces it.
var defaultFeedURL = "https://raw.githubusercontent.com/Naidez7/vsrghub/main/release/vsrghub-feed.json"

// launcherDir is the launcher's own folder in the user's AppData (its settings, its log while no
// Etterna is known, the WebView2 loader when the program runs on its own).
func launcherDir() string {
	base := os.Getenv("LOCALAPPDATA")
	if base == "" {
		base = os.TempDir()
	}
	d := filepath.Join(base, "VSRG Hub")
	os.MkdirAll(d, 0o755)
	return d
}

// the launcher's own settings: where Etterna is and where the launcher was put
type launcherConfig struct {
	Etterna  string `json:"etterna"`
	Launcher string `json:"launcher"` // the installed launcher's path (Install the launcher)
}

func loadLauncherConfig() launcherConfig {
	var c launcherConfig
	readFileJSON(filepath.Join(launcherDir(), "launcher.json"), &c)
	return c
}

func saveLauncherConfig(c launcherConfig) {
	b, _ := json.MarshalIndent(c, "", "  ")
	os.WriteFile(filepath.Join(launcherDir(), "launcher.json"), b, 0o644)
}

// isEtternaDir: an Etterna install (its Program\Etterna.exe).
func isEtternaDir(d string) bool {
	if d == "" {
		return false
	}
	st, err := os.Stat(filepath.Join(d, "Program", "Etterna.exe"))
	return err == nil && !st.IsDir()
}

// etternaFromPick takes the folder the player chose: Etterna's own, its Program folder, or a folder
// holding it.
func etternaFromPick(d string) string {
	for _, c := range []string{d, filepath.Dir(d), filepath.Join(d, "Etterna")} {
		if isEtternaDir(c) {
			return c
		}
	}
	return ""
}

// findEtterna looks where Etterna's installer and people usually put it.
func findEtterna() string {
	var cands []string
	cands = append(cands, registryEtternaDirs()...)
	for _, r := range driveRoots() {
		for _, sub := range []string{`Games\Etterna`, `Etterna`, `Program Files\Etterna`, `Program Files (x86)\Etterna`, `Juegos\Etterna`} {
			cands = append(cands, filepath.Join(r, sub))
		}
	}
	if h := os.Getenv("USERPROFILE"); h != "" {
		for _, sub := range []string{`Etterna`, `Desktop\Etterna`, `Documents\Etterna`, `Downloads\Etterna`, `Games\Etterna`} {
			cands = append(cands, filepath.Join(h, sub))
		}
	}
	for _, c := range cands {
		if isEtternaDir(c) {
			return c
		}
	}
	return ""
}

// installedVersion is the VSRG Hub version in an Etterna's VSRGHub folder ("" when none is there).
func installedVersion(home string) string {
	if _, err := os.Stat(filepath.Join(home, "vsrghub.exe")); err != nil {
		return ""
	}
	if !dirExists(filepath.Join(home, "Root", "Themes")) {
		return ""
	}
	b, err := os.ReadFile(filepath.Join(home, "version.txt"))
	if err != nil {
		return "?"
	}
	return strings.TrimSpace(string(b))
}

// The update feed: the newest version (where its zip is) and every version's notes.
type updateFeed struct {
	onlineUpdate
	Latest    *onlineUpdate `json:"latest"`
	Launcher  *onlineUpdate `json:"launcher"`
	Changelog []changeEntry `json:"changelog"`
}

// --- Etterna's video settings, for the launcher's Options ---

// what the launcher's Options show and change in Etterna's Preferences.ini
var prefKeys = []string{"DisplayWidth", "DisplayHeight", "DisplayAspectRatio", "Windowed", "FullscreenIsBorderlessWindow",
	"RefreshRate", "Vsync", "FrameLimit", "FrameLimitGameplay", "VideoRenderers", "ShowStats"}

func readPrefs(etterna string) map[string]string {
	m := map[string]string{}
	b, err := os.ReadFile(prefsPath(etterna))
	if err != nil {
		return m
	}
	in := false
	for _, l := range strings.Split(strings.ReplaceAll(string(b), "\r", ""), "\n") {
		if strings.HasPrefix(l, "[") {
			in = l == "[Options]"
			continue
		}
		if k, v, ok := strings.Cut(l, "="); ok && in {
			m[k] = v
		}
	}
	return m
}

// writePrefs sets keys in Preferences.ini's [Options], keeping everything else (and adds the ones
// that aren't there, in alphabetical place as Etterna writes them).
func writePrefs(etterna string, set map[string]string) error {
	p := prefsPath(etterna)
	b, err := os.ReadFile(p)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	text := string(b)
	nl := "\r\n"
	if text != "" && !strings.Contains(text, "\r\n") {
		nl = "\n"
	}
	lines := strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n")
	if text == "" {
		lines = []string{"[Options]"}
	}
	start := -1
	for i, l := range lines {
		if l == "[Options]" {
			start = i
			break
		}
	}
	if start < 0 {
		lines = append([]string{"[Options]", ""}, lines...)
		start = 0
	}
	end := len(lines)
	for i := start + 1; i < len(lines); i++ {
		if strings.HasPrefix(lines[i], "[") {
			end = i
			break
		}
	}
	done := map[string]bool{}
	for i := start + 1; i < end; i++ {
		if k, _, ok := strings.Cut(lines[i], "="); ok {
			if v, want := set[k]; want {
				lines[i] = k + "=" + v
				done[k] = true
			}
		}
	}
	var missing []string
	for k := range set {
		if !done[k] {
			missing = append(missing, k)
		}
	}
	sort.Strings(missing)
	for _, k := range missing {
		at := end
		for i := start + 1; i < end; i++ {
			if lk, _, ok := strings.Cut(lines[i], "="); ok && lk > k {
				at = i
				break
			}
		}
		lines = append(lines[:at], append([]string{k + "=" + set[k]}, lines[at:]...)...)
		end++
	}
	os.MkdirAll(filepath.Dir(p), 0o755)
	return os.WriteFile(p, []byte(strings.Join(lines, nl)), 0o644)
}

// launcherOptions: Etterna's video settings in the launcher's words.
func launcherOptions(etterna string) map[string]any {
	p := readPrefs(etterna)
	num := func(k string, def int) int {
		if v, err := strconv.Atoi(strings.TrimSpace(p[k])); err == nil {
			return v
		}
		if f, err := strconv.ParseFloat(strings.TrimSpace(p[k]), 64); err == nil {
			return int(f)
		}
		return def
	}
	mode := "fullscreen"
	if p["Windowed"] == "1" {
		mode = "windowed"
	} else if p["FullscreenIsBorderlessWindow"] == "1" {
		mode = "borderless"
	}
	renderer := "d3d"
	if strings.HasPrefix(strings.ToLower(strings.TrimSpace(p["VideoRenderers"])), "opengl") {
		renderer = "opengl"
	}
	return map[string]any{
		"width": num("DisplayWidth", 1280), "height": num("DisplayHeight", 720), "mode": mode,
		"refresh": num("RefreshRate", 0), "vsync": p["Vsync"] == "1",
		"frameLimit": num("FrameLimit", 0), "frameLimitGameplay": num("FrameLimitGameplay", 0),
		"renderer": renderer, "showStats": p["ShowStats"] == "1",
	}
}

// setLauncherOption changes one of them.
func setLauncherOption(etterna, key string, value any) error {
	str := func() string {
		switch v := value.(type) {
		case string:
			return v
		case float64:
			return strconv.Itoa(int(v))
		case bool:
			if v {
				return "1"
			}
			return "0"
		}
		return ""
	}
	set := map[string]string{}
	switch key {
	case "resolution": // "1920x1080"
		w, h, ok := strings.Cut(str(), "x")
		wi, e1 := strconv.Atoi(w)
		hi, e2 := strconv.Atoi(h)
		if !ok || e1 != nil || e2 != nil || wi < 320 || hi < 240 {
			return nil
		}
		set["DisplayWidth"], set["DisplayHeight"] = w, h
		set["DisplayAspectRatio"] = strconv.FormatFloat(float64(wi)/float64(hi), 'f', 6, 64)
	case "mode":
		switch str() {
		case "fullscreen":
			set["Windowed"], set["FullscreenIsBorderlessWindow"] = "0", "0"
		case "borderless":
			set["Windowed"], set["FullscreenIsBorderlessWindow"] = "0", "1"
		case "windowed":
			set["Windowed"] = "1"
		}
	case "refresh":
		set["RefreshRate"] = str()
	case "vsync":
		set["Vsync"] = str()
	case "frameLimit":
		set["FrameLimit"] = str()
	case "frameLimitGameplay":
		set["FrameLimitGameplay"] = str()
	case "renderer":
		if str() == "opengl" {
			set["VideoRenderers"] = "opengl,d3d"
		} else {
			set["VideoRenderers"] = "d3d,opengl"
		}
	case "showStats":
		set["ShowStats"] = str()
	}
	if len(set) == 0 {
		return nil
	}
	return writePrefs(etterna, set)
}

// a folder picked for one of the games: is it that game's?
func checkGameDir(id, d string) (string, bool) {
	switch id {
	case "osu":
		if isOsuDir(d) || dirExists(filepath.Join(d, "Songs")) {
			return d, true
		}
		if isOsuDir(filepath.Dir(d)) { // (its Songs folder)
			return filepath.Dir(d), true
		}
		return "This isn't an osu! folder (it has no osu!.exe or Songs folder). VSRG Hub reads osu!stable; osu!lazer keeps its songs in a form VSRG Hub can't read.", false
	case "quaver":
		for _, c := range []string{d, filepath.Dir(d)} {
			if fileExists(filepath.Join(c, "Quaver.exe")) || dirExists(filepath.Join(c, "Songs")) || fileExists(filepath.Join(c, "quaver.db")) {
				return c, true
			}
		}
		return "This isn't a Quaver folder (it has no Quaver.exe or Songs folder).", false
	case "qwilight":
		for _, c := range []string{d, filepath.Dir(d)} {
			if dirExists(filepath.Join(c, "SavesDir")) || fileExists(filepath.Join(c, "Qwilight.exe")) {
				return c, true
			}
		}
		return "This isn't a Qwilight folder (it has no Qwilight.exe or SavesDir folder).", false
	}
	return d, true
}

func copyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	tmp := dst + ".new"
	if err := os.WriteFile(tmp, b, 0o755); err != nil {
		return err
	}
	os.Remove(dst)
	return os.Rename(tmp, dst)
}

// replaceSelf puts src (a newer vsrghub.exe) in this program's place: the running file is moved
// aside first (Windows lets a running program be renamed, not overwritten). Returns this program's path.
func replaceSelf(src string) (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	if a, b := filepath.Clean(exe), filepath.Clean(src); strings.EqualFold(a, b) {
		return exe, nil
	}
	// the running program is moved aside (Windows lets a running .exe be renamed, not overwritten)
	// and the new one copied in its place. An ".old" left by the last update may still be held
	// (by the program that was just replaced, still closing, or by the antivirus looking at it):
	// then a fresh name is used, and the leftovers are cleared on the next start.
	old := exe + ".old"
	os.Remove(old)
	if err := os.Rename(exe, old); err != nil {
		old = fmt.Sprintf("%s.old%d", exe, time.Now().Unix()%100000)
		if err2 := os.Rename(exe, old); err2 != nil {
			return "", err
		}
	}
	if err := copyFile(src, exe); err != nil {
		os.Rename(old, exe)
		return "", err
	}
	return exe, nil
}

// clearOldSelves removes what earlier updates of the launcher left beside it
func clearOldSelves(exe string) {
	olds, _ := filepath.Glob(exe + ".old*")
	for _, o := range olds {
		os.Remove(o)
	}
}

// replaceSelfAndRestart: replaceSelf, then the new program is started with the same arguments.
func replaceSelfAndRestart(src string) error {
	exe, err := replaceSelf(src)
	if err != nil {
		return err
	}
	cmd := exec.Command(exe, os.Args[1:]...)
	cmd.Dir = filepath.Dir(exe)
	if err := cmd.Start(); err != nil {
		return err
	}
	logf("launcher: now %s; started again", src)
	return nil
}

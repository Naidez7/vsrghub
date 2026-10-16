// VSRG Hub: Etterna's song wheel with your own Quaver and Qwilight libraries in it.
//
// Melty starts this program instead of Etterna. It reads the player's Quaver and
// Qwilight folders where they are, builds a small library folder of generated
// .sm charts and directory junctions (nothing is copied), points Etterna at it
// through ETTERNA_ADDITIONAL_SONG_DIRS, and starts Etterna.
package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"time"
)

// version is set by the build (-ldflags "-X main.version=..."), from the version being packaged
var version = "dev"

// converterVersion changes only when chart conversion changes, so updates that only touch the
// interface keep the song cache (a full rescan of a big osu! library takes minutes).
const converterVersion = "1.4.1"

var logFile *os.File

// dataDir: Etterna's Save/VSRGHub, where what survives a new VSRGHub folder is kept
var dataDir string

var logMu sync.Mutex

// noteskinLogged keeps noteskin notes from being repeated (one per column, one per noteskin built
// from the same skin): each is written once per run.
var noteskinLogged = map[string]bool{}

func logf(format string, a ...any) {
	logMu.Lock()
	defer logMu.Unlock()
	msg := fmt.Sprintf(format, a...)
	if strings.HasPrefix(msg, "noteskin: ") {
		if noteskinLogged[msg] {
			return
		}
		noteskinLogged[msg] = true
	}
	line := fmt.Sprintf("%s %s\n", time.Now().Format("15:04:05"), msg)
	if logFile != nil {
		logFile.WriteString(line)
	}
	fmt.Print(line)
}

type manifest struct {
	Version string   `json:"version"`
	Entries []string `json:"entries"` // library-relative paths VSRG Hub created
}

type report struct {
	QuaverSongs, QuaverCharts, QuaverSkipped int
	QwilightSongs, QwilightPacks             int
	OsuSongs, OsuCharts, OsuSkipped          int
}

func main() {
	var dirs = map[string]*string{}
	for _, g := range Games {
		dirs[g.ID] = flag.String(strings.TrimPrefix(g.ArgFlag, "--"), "", g.Name+" install folder")
	}
	buildOnly := flag.Bool("build-only", false, "build the library and exit without starting Etterna")
	playNow := flag.Bool("play", false, "start the game straight away, without the launcher window")
	// a VSRG Hub zip dropped on vsrghub.exe (or passed to it) installs that version
	var zipArgs []string
	var rest []string
	for _, a := range os.Args[1:] {
		if strings.EqualFold(filepath.Ext(a), ".zip") {
			zipArgs = append(zipArgs, a)
		} else {
			rest = append(rest, a)
		}
	}
	flag.CommandLine.Parse(rest)

	etterna := *dirs["etterna"]
	exe, _ := os.Executable()
	exeDir := filepath.Dir(exe)
	// Where VSRG Hub runs from: Etterna's VSRGHub folder (Melty puts it there; the zip unpacks
	// there), or anywhere else as the launcher on its own (launcherhost.go), which finds Etterna or
	// is told where it is.
	standalone := false
	if etterna == "" {
		if strings.EqualFold(filepath.Base(exeDir), "VSRGHub") {
			etterna = filepath.Dir(exeDir) // {game}/VSRGHub/vsrghub.exe
		} else {
			standalone = true
			cfg := loadLauncherConfig()
			if isEtternaDir(cfg.Etterna) {
				etterna = cfg.Etterna
			} else if d := findEtterna(); d != "" {
				etterna = d
				cfg.Etterna = d
				saveLauncherConfig(cfg)
			}
		}
	}
	clearOldSelves(exe) // (left by the launcher updating itself)
	if standalone {
		if f, err := os.Create(filepath.Join(launcherDir(), "launcher.log")); err == nil {
			logFile = f
			defer f.Close()
		}
		logf("VSRG Hub %s (launcher at %s)", version, exe)
		if etterna == "" {
			logf("Etterna: not found")
			for _, g := range Games {
				if g.ID != "etterna" && *dirs[g.ID] == "" {
					*dirs[g.ID] = findGameDir(g.ID)
				}
			}
			l := &launch{standalone: true, dirs: dirs}
			if _, _, ok := runLauncher(l); !ok {
				launcherUnavailable()
			}
			return
		}
		// a newer VSRG Hub in Etterna's folder (installed or updated by Melty, or another launcher):
		// this launcher becomes that version first
		home := filepath.Join(etterna, "VSRGHub")
		if v := installedVersion(home); v != "" && v != "?" && newerVersion(v, version) && !*buildOnly {
			if err := replaceSelfAndRestart(filepath.Join(home, "vsrghub.exe")); err == nil {
				return
			} else {
				logf("launcher: updating itself to %s: %v", v, err)
			}
		}
	}
	home := filepath.Join(etterna, "VSRGHub")
	os.MkdirAll(home, 0o755)
	if !standalone {
		if f, err := os.Create(filepath.Join(home, "vsrghub.log")); err == nil {
			logFile = f
			defer f.Close()
		}
		logf("VSRG Hub %s", version)
	}
	logf("Etterna: %s", etterna)
	// what VSRG Hub keeps between versions (the converted songs, the folders it found, the theme to
	// put back) lives in Etterna's Save folder, so a new VSRGHub folder starts where the old one was
	data := filepath.Join(etterna, "Save", "VSRGHub")
	os.MkdirAll(data, 0o755)
	dataDir = data
	migrateOldName(etterna, home)
	migrateToData(home, data)
	if (!standalone || len(zipArgs) > 0) && updateFromZip(etterna, home, data, zipArgs) {
		return // the new version was started in this one's place
	}
	// Started without the game folders (e.g. by opening vsrghub.exe directly): use the ones from the
	// last launch, or find them, so the library and skins are never emptied by mistake.
	known := loadKnownDirs(data)
	for _, g := range Games {
		if g.ID == "etterna" {
			continue
		}
		// (a game the player doesn't have: Melty may pass an empty or unfilled folder; VSRG Hub
		// then simply goes without that game's songs and skins)
		if d := *dirs[g.ID]; d != "" && (strings.Contains(d, "{") || !dirExists(d) ||
			(g.ID == "osu" && !isOsuDir(d) && !dirExists(filepath.Join(d, "Songs")))) {
			logf("%s: no folder at %q, looking for it", g.Name, d)
			*dirs[g.ID] = ""
		}
		if *dirs[g.ID] == "" {
			if d := known[g.ID]; d != "" && dirExists(d) {
				*dirs[g.ID] = d
			} else if d := findGameDir(g.ID); d != "" {
				*dirs[g.ID] = d
			}
		}
		if *dirs[g.ID] != "" && dirExists(*dirs[g.ID]) {
			known[g.ID] = *dirs[g.ID]
		}
	}
	if *dirs["osu"] == "" {
		if lazer := filepath.Join(os.Getenv("APPDATA"), "osu"); dirExists(filepath.Join(lazer, "files")) {
			logf("osu!: only osu!lazer found (%s); VSRG Hub reads osu!stable's Songs folder, which lazer doesn't have", lazer)
		} else {
			logf("osu!: not found; start vsrghub.exe with --osu \"<your osu! folder>\" if you have it")
		}
	}
	saveKnownDirs(data, known)
	for _, g := range Games {
		logf("%s (%s): %s", g.Name, g.Role, *dirs[g.ID])
	}
	l := &launch{etterna: etterna, home: home, data: data, dirs: dirs, buildOnly: *buildOnly, args: flag.Args(), standalone: standalone}
	// opened by itself (the desktop shortcut, a double click): the launcher window first. Started
	// with the game folders (Melty) or --play: straight into the game.
	if !*playNow && !*buildOnly && flag.NFlag() == 0 && len(flag.Args()) == 0 && len(zipArgs) == 0 {
		if cmd, done, ok := runLauncher(l); ok {
			if cmd != nil {
				// (VSRG Hub online while the game runs: scores sent, rankings read: online.go)
				stopOnline := startOnlineService(data)
				stopTray := startTray(func() string { return trayTip(data) })
				stopPresence := startPresence(data, true)
				cmd.Wait()
				stopPresence()
				stopTray()
				stopOnline()
				done()
				logf("Etterna exited")
			} else if done != nil {
				// (the launcher window closed with the game running under its care: wait for it)
				done()
			}
			return
		}
		logf("launcher: not available here, starting the game")
		if standalone {
			launcherUnavailable()
		}
	}
	if standalone && installedVersion(home) == "" {
		logf("VSRG Hub isn't installed in %s; start the launcher to install it", home)
		os.Exit(1)
	}
	cmd, done, err := l.start(func(string) {})
	if err != nil {
		logf("%v", err)
		os.Exit(1)
	}
	if cmd == nil {
		return
	}
	stopOnline := startOnlineService(data)
	stopTray := startTray(func() string { return trayTip(data) })
	stopPresence := startPresence(data, true)
	cmd.Wait()
	stopPresence()
	stopTray()
	stopOnline()
	done()
	logf("Etterna exited")
}

// launch is what starting the game needs: the folders found above.
type launch struct {
	etterna, home, data string
	dirs                map[string]*string
	buildOnly           bool
	args                []string
	standalone          bool // the launcher on its own, not the copy in Etterna's VSRGHub folder
	importNew           func()             // your new osu! / Quaver plays, looked for in the background (launcher_windows.go)
	beforeGame          func(func(string)) // run before Etterna starts, with the game closed (launcher_windows.go)
}

// start brings the library and theme folder up to date and starts Etterna. progress gets a word
// on each step (the launcher shows it). It returns the running game and what to do once it ends
// (nil, nil when only building).
func (l *launch) start(progress func(string)) (*exec.Cmd, func(), error) {
	etterna, data, home, dirs := l.etterna, l.data, l.home, l.dirs
	go writeUpdateNotice(home, data)
	os.MkdirAll(filepath.Join(data, "menu"), 0o755) // (your own main menu pictures go here: Options > Menu background)
	progress("Reading your songs")
	lib := filepath.Join(data, "Library")
	rep, err := buildLibrary(lib, *dirs["quaver"], *dirs["qwilight"], *dirs["osu"])
	if err != nil {
		logf("library: %v", err)
	}
	logf("Quaver: %d songs, %d charts (%d charts skipped). osu!: %d songs, %d charts (%d skipped). Qwilight: %d songs, %d packs.",
		rep.QuaverSongs, rep.QuaverCharts, rep.QuaverSkipped, rep.OsuSongs, rep.OsuCharts, rep.OsuSkipped, rep.QwilightSongs, rep.QwilightPacks)
	// (the song list's small pictures: made in the background while the game starts)
	if l.buildOnly {
		makeThumbs(lib, thumbGroups)
	} else {
		go makeThumbs(lib, thumbGroups)
	}
	root := filepath.Join(home, "Root")
	progress("Setting up skins and themes")
	buildRoot(root, etterna, *dirs["osu"], *dirs["quaver"], buildCollections(lib, *dirs["osu"]))
	if l.buildOnly {
		return nil, nil, nil
	}

	exe := filepath.Join(etterna, "Program", "Etterna.exe")
	if _, err := os.Stat(exe); err != nil {
		return nil, nil, fmt.Errorf("Etterna.exe not found at %s", exe)
	}
	// (your new osu! / Quaver plays handed to the game, and the rated ones written to the Etterna
	// profile: before the game reads it)
	if l.beforeGame != nil {
		l.beforeGame(progress)
	}
	progress("Starting Etterna")
	env := os.Environ()
	songDirs := filepath.ToSlash(lib)
	for i, kv := range env {
		if strings.HasPrefix(strings.ToUpper(kv), "ETTERNA_ADDITIONAL_SONG_DIRS=") {
			if old := kv[len("ETTERNA_ADDITIONAL_SONG_DIRS="):]; old != "" {
				songDirs = old + ";" + songDirs
			}
			env = append(env[:i], env[i+1:]...)
			break
		}
	}
	env = append(env, "ETTERNA_ADDITIONAL_SONG_DIRS="+songDirs)
	env = setEnvList(env, "ETTERNA_ADDITIONAL_ROOT_DIRS", filepath.ToSlash(root))
	// Etterna drops Theme= from Preferences.ini while VSRG Hub's Static.ini is in use; remember the
	// player's own theme (also across launches, in case an earlier run was cut short) and put it back.
	userTheme := readPrefTheme(etterna)
	st := loadState(data)
	if userTheme != "" && !isOurTheme(userTheme) {
		if st.EtternaTheme != userTheme {
			st.EtternaTheme = userTheme
			saveState(data, st)
		}
	} else {
		userTheme = firstNonEmpty(st.EtternaTheme, "Til Death")
	}
	// the profile page's EtternaOnline (eo.go), while Etterna runs
	stopEO := startEO(data)
	stopDev := startDevSync(home)
	cmd := exec.Command(exe, l.args...)
	cmd.Dir = filepath.Dir(exe)
	cmd.Env = env
	if err := cmd.Start(); err != nil {
		stopEO()
		stopDev()
		restorePrefTheme(etterna, userTheme)
		return nil, nil, fmt.Errorf("start Etterna: %v", err)
	}
	logf("started Etterna (pid %d) with songs from %s and theme/noteskins from %s", cmd.Process.Pid, songDirs, filepath.ToSlash(root))
	if logFile != nil {
		logFile.Sync()
	}
	return cmd, func() { stopEO(); stopDev(); restorePrefTheme(etterna, userTheme) }, nil
}

func buildLibrary(lib, quaverDir, qwilightDir, osuDir string) (report, error) {
	var rep report
	if err := os.MkdirAll(lib, 0o755); err != nil {
		return rep, err
	}
	var old manifest
	if b, err := os.ReadFile(filepath.Join(lib, "triwheel-manifest.json")); err == nil {
		json.Unmarshal(b, &old)
	}
	keep := map[string]bool{}
	var oldCache cacheFile
	if b, err := os.ReadFile(filepath.Join(lib, "triwheel-cache.json")); err == nil {
		json.Unmarshal(b, &oldCache)
	}
	if oldCache.Version == "1.4.0" {
		// 1.4.1 only renamed the songs of sets split into several (rates, packs): just those are read again
		for k, c := range oldCache.Sets {
			if len(c.Songs) > 1 {
				delete(oldCache.Sets, k)
			}
		}
		oldCache.Version = converterVersion
	}
	if oldCache.Version != converterVersion {
		oldCache.Sets = nil
	}
	newCache := cacheFile{Version: converterVersion, Sets: map[string]cacheEntry{}}
	defer func() {
		b, _ := json.Marshal(newCache)
		os.WriteFile(filepath.Join(lib, "triwheel-cache.json"), b, 0o644)
	}()

	if quaverDir != "" {
		songsDir := quaverSongDir(quaverDir)
		logf("Quaver songs folder: %s", songsDir)
		n, c, k := convertGroup(lib, "Quaver", songsDir, scanQuaverSet, oldCache, newCache, keep)
		rep.QuaverSongs, rep.QuaverCharts, rep.QuaverSkipped = n, c, k
	}
	if osuDir != "" {
		songsDir := osuSongDir(osuDir)
		logf("osu! songs folder: %s", songsDir)
		n, c, k := convertGroup(lib, "osu!", songsDir, scanOsuSet, oldCache, newCache, keep)
		rep.OsuSongs, rep.OsuCharts, rep.OsuSkipped = n, c, k
	}

	if qwilightDir != "" {
		bundle := filepath.Join(qwilightDir, "SavesDir", "Bundle")
		logf("Qwilight bundle folder: %s", bundle)
		entries, err := os.ReadDir(bundle)
		if err != nil {
			logf("qwilight: %v", err)
		}
		group := filepath.Join(lib, "Qwilight")
		os.MkdirAll(group, 0o755)
		keepAdd(keep, "Qwilight")
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			src := filepath.Join(bundle, e.Name())
			switch {
			case hasCharts(src):
				rel := filepath.Join("Qwilight", safeName(e.Name()))
				if err := ensureJunction(filepath.Join(lib, rel), src); err != nil {
					logf("qwilight: %s: %v", e.Name(), err)
					continue
				}
				keepAdd(keep, rel)
				rep.QwilightSongs++
			case len(chartSubdirs(src)) == 1: // a song inside a wrapper folder (as unzipped)
				rel := filepath.Join("Qwilight", safeName(e.Name()))
				if err := ensureJunction(filepath.Join(lib, rel), chartSubdirs(src)[0]); err != nil {
					logf("qwilight: %s: %v", e.Name(), err)
					continue
				}
				keepAdd(keep, rel)
				rep.QwilightSongs++
			case len(chartSubdirs(src)) > 1:
				rel := "Qwilight - " + safeName(e.Name())
				if err := ensureJunction(filepath.Join(lib, rel), src); err != nil {
					logf("qwilight: %s: %v", e.Name(), err)
					continue
				}
				keepAdd(keep, rel)
				rep.QwilightPacks++
			}
		}
	}

	cleanOwned(lib, old, keep)
	return rep, nil
}

// removeOwned deletes a junction (never its target), a generated file, or an empty folder.
func removeOwned(p string) {
	if isLink(p) {
		removeLink(p)
		return
	}
	st, err := os.Lstat(p)
	if err != nil {
		return
	}
	if st.IsDir() {
		os.Remove(filepath.Join(p, thumbName)) // (the song's thumbnail, ours: thumbs.go)
		os.Remove(filepath.Join(p, thumbNone))
		os.Remove(filepath.Join(p, bigName))
		os.Remove(p) // only succeeds when empty
		return
	}
	switch strings.ToLower(filepath.Ext(p)) {
	case ".sm", ".lua", ".ini":
		os.Remove(p)
	}
}

var chartExts = map[string]bool{".bms": true, ".bme": true, ".bml": true, ".pms": true}

func hasCharts(dir string) bool {
	es, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	for _, e := range es {
		if !e.IsDir() && chartExts[strings.ToLower(filepath.Ext(e.Name()))] {
			return true
		}
	}
	return false
}

func chartSubdirs(dir string) []string {
	es, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range es {
		if e.IsDir() && hasCharts(filepath.Join(dir, e.Name())) {
			out = append(out, filepath.Join(dir, e.Name()))
		}
	}
	return out
}

type cacheEntry struct {
	Sig    string   `json:"sig"`
	Songs  []string `json:"songs"`
	Charts int      `json:"charts"`
}

type cacheFile struct {
	Version string                `json:"version"`
	Sets    map[string]cacheEntry `json:"sets"`
}

// setSignature changes whenever a chart or audio file in the set is added, removed or edited.
func setSignature(dir string) string {
	es, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	var sb strings.Builder
	for _, e := range es {
		if e.IsDir() {
			continue
		}
		if info, err := e.Info(); err == nil {
			fmt.Fprintf(&sb, "%s|%d|%d;", e.Name(), info.Size(), info.ModTime().UnixNano())
		}
	}
	return sb.String()
}

func cachedSongsPresent(group string, songs []string) bool {
	for _, n := range songs {
		if _, err := os.Stat(filepath.Join(group, n, n+".sm")); err != nil {
			return false
		}
		if !isLink(filepath.Join(group, n, "src")) {
			return false
		}
	}
	return true
}

// quaverSongDir reads SongDirectory from the player's quaver.cfg (games sheet: contentRootConfig).
func quaverSongDir(quaver string) string {
	def := filepath.Join(quaver, "Songs")
	f, err := os.Open(filepath.Join(quaver, "quaver.cfg"))
	if err != nil {
		return def
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		k, v, ok := strings.Cut(line, "=")
		if ok && strings.TrimSpace(k) == "SongDirectory" {
			v = strings.TrimSpace(v)
			if v != "" {
				if st, err := os.Stat(v); err == nil && st.IsDir() {
					return v
				}
			}
		}
	}
	return def
}

func keepAdd(keep map[string]bool, rel string) { keep[filepath.ToSlash(rel)] = true }

// convertGroup writes one Etterna group of generated .sm songs from a folder of map sets.
func convertGroup(lib, groupName, songsDir string, scan func(string, func(string, ...any)) []*quaverSong,
	oldCache, newCache cacheFile, keep map[string]bool) (songs, charts, skippedN int) {
	sets, err := os.ReadDir(songsDir)
	if err != nil {
		logf("%s: %v", groupName, err)
	}
	group := filepath.Join(lib, groupName)
	used := map[string]bool{}
	keepAdd(keep, groupName)
	// Read the sets that changed in parallel; writing stays in order below.
	scanned := make([][]*quaverSong, len(sets))
	sigs := make([]string, len(sets))
	jobs := make(chan int)
	var wg sync.WaitGroup
	for w := 0; w < max(2, runtime.NumCPU()); w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				setDir := filepath.Join(songsDir, sets[i].Name())
				sigs[i] = setSignature(setDir)
				if c, ok := oldCache.Sets[groupName+"|"+sets[i].Name()]; ok && c.Sig == sigs[i] {
					continue
				}
				scanned[i] = scan(setDir, logf)
			}
		}()
	}
	for i, set := range sets {
		if set.IsDir() {
			jobs <- i
		}
	}
	close(jobs)
	wg.Wait()
	for si, set := range sets {
		if !set.IsDir() {
			continue
		}
		sig := sigs[si]
		key := groupName + "|" + set.Name()
		if c, ok := oldCache.Sets[key]; ok && c.Sig == sig && cachedSongsPresent(group, c.Songs) {
			for _, name := range c.Songs {
				used[strings.ToLower(name)] = true
				rel := filepath.Join(groupName, name)
				keepAdd(keep, rel+"/src")
				keepAdd(keep, rel+"/"+name+".sm")
				keepAdd(keep, rel)
			}
			newCache.Sets[key] = c
			songs += len(c.Songs)
			charts += c.Charts
			continue
		}
		entry := cacheEntry{Sig: sig}
		songsHere := scanned[si]
		if songsHere == nil { // cached but its files went missing: read it again
			songsHere = scan(filepath.Join(songsDir, set.Name()), logf)
		}
		for _, song := range songsHere {
			name := song.name
			for i := 2; used[strings.ToLower(name)]; i++ {
				name = fmt.Sprintf("%s [%d]", song.name, i)
			}
			used[strings.ToLower(name)] = true
			sm, skipped, err := song.writeSM("src/")
			for _, s := range skipped {
				logf("%s: skipped %s/%s", groupName, set.Name(), s)
			}
			skippedN += len(skipped)
			if err != nil {
				logf("%s: %s: %v", groupName, set.Name(), err)
				continue
			}
			dir := filepath.Join(group, name)
			os.MkdirAll(dir, 0o755)
			if err := ensureJunction(filepath.Join(dir, "src"), song.setDir); err != nil {
				logf("%s: %s: junction: %v", groupName, name, err)
				continue
			}
			smPath := filepath.Join(dir, name+".sm")
			if b, err := os.ReadFile(smPath); err != nil || string(b) != sm {
				if err := os.WriteFile(smPath, []byte(sm), 0o644); err != nil {
					logf("%s: %s: %v", groupName, name, err)
					continue
				}
			}
			rel := filepath.Join(groupName, name)
			keepAdd(keep, rel+"/src")
			keepAdd(keep, rel+"/"+name+".sm")
			keepAdd(keep, rel)
			songs++
			charts += len(song.maps) - len(skipped)
			entry.Songs = append(entry.Songs, name)
			entry.Charts += len(song.maps) - len(skipped)
		}
		newCache.Sets[key] = entry
	}
	return
}

// cleanOwned removes what an earlier run made and this run did not (links and our own files only),
// then records what this run made.
func cleanOwned(dir string, old manifest, keep map[string]bool) {
	sort.Sort(sort.Reverse(sort.StringSlice(old.Entries)))
	for _, rel := range old.Entries {
		if keep[filepath.ToSlash(rel)] {
			continue
		}
		removeOwned(filepath.Join(dir, rel))
	}
	var m manifest
	m.Version = version
	for k := range keep {
		m.Entries = append(m.Entries, filepath.ToSlash(k))
	}
	sort.Strings(m.Entries)
	b, _ := json.MarshalIndent(m, "", "  ")
	os.WriteFile(filepath.Join(dir, "triwheel-manifest.json"), b, 0o644)
}

func readFileJSON(path string, v any) ([]byte, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return b, json.Unmarshal(b, v)
}

// setEnvList appends dir to a ;-separated variable, keeping any value the player already set.
func setEnvList(env []string, name, dir string) []string {
	val := dir
	for i, kv := range env {
		if strings.HasPrefix(strings.ToUpper(kv), name+"=") {
			if old := kv[len(name)+1:]; old != "" {
				val = old + ";" + dir
			}
			env = append(env[:i], env[i+1:]...)
			break
		}
	}
	return append(env, name+"="+val)
}

// migrateOldName carries over what the launcher kept under its old name, TriWheel (up to
// 1.8.0-beta.9): the converted song library (so nothing is converted again), the player's
// settings, layout and keybinds in Save, and the Full LN / Inverse charts in Songs. Only when the new places don't exist yet.
// migrateToData moves what earlier versions kept in the VSRGHub folder into the data folder (once).
// Etterna reaches the songs as /AdditionalSongs either way, so it doesn't read them again.
func migrateToData(home, data string) {
	if from, to := filepath.Join(home, "Library"), filepath.Join(data, "Library"); dirExists(from) && !dirExists(to) {
		if err := os.Rename(from, to); err != nil {
			logf("moving %s to %s: %v", from, to, err)
		} else {
			logf("moved %s to %s", from, to)
		}
	}
	for _, f := range []string{"triwheel-dirs.json", "triwheel-state.json"} {
		from, to := filepath.Join(home, "Root", f), filepath.Join(data, f)
		if _, err := os.Stat(to); err != nil {
			if b, err := os.ReadFile(from); err == nil {
				os.WriteFile(to, b, 0o644)
			}
		}
	}
}

func migrateOldName(etterna, home string) {
	move := func(from, to string) {
		if !dirExists(from) || dirExists(to) {
			return
		}
		if err := os.Rename(from, to); err != nil {
			logf("moving %s to %s: %v", from, to, err)
		} else {
			logf("moved %s to %s", from, to)
		}
	}
	move(filepath.Join(etterna, "TriWheel", "Library"), filepath.Join(etterna, "Save", "VSRGHub", "Library"))
	move(filepath.Join(etterna, "Save", "TriWheel"), filepath.Join(etterna, "Save", "VSRGHub"))
	// (the Full LN / Inverse copies of charts the theme made)
	move(filepath.Join(etterna, "Songs", "TriWheel Mods"), filepath.Join(etterna, "Songs", "VSRG Hub Mods"))
}

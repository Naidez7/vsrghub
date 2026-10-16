//go:build windows

package main

// The launcher: the window vsrghub.exe opens when it is started by itself (the desktop shortcut,
// a double click). Play and the look to start in; your games' folders; installing and updating
// VSRG Hub; every version's notes; Etterna's display options. It is a web page in a WebView2 window
// (Windows' built-in Edge engine); without WebView2 the game starts straight away as before.

import (
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"unsafe"

	webview2 "github.com/jchv/go-webview2"
	"golang.org/x/sys/windows"
)

//go:embed assets/launcher.html
var launcherHTML string

//go:embed assets/launcher-icon.png
var launcherIcon []byte

var importMu sync.Mutex // (one look at the replays at a time)

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func runLauncher(l *launch) (*exec.Cmd, func(), bool) {
	runtime.LockOSThread()
	prepareWebView2()
	scale := dpiScale()
	// (the page's own dark colour while it loads, not a white flash; WebView2 reads this, ARGB)
	os.Setenv("WEBVIEW2_DEFAULT_BACKGROUND_COLOR", "FF0B0912")
	const winW, winH = 1120, 680
	w := webview2.NewWithOptions(webview2.WebViewOptions{
		Debug:     false,
		AutoFocus: true,
		DataPath:  filepath.Join(launcherDir(), "webview"),
		WindowOptions: webview2.WindowOptions{
			Title:  "VSRG Hub",
			Width:  uint(winW * scale),
			Height: uint(winH * scale),
			IconId: 1,
			Center: true,
		},
	})
	if w == nil {
		logf("launcher: the WebView2 window couldn't be made (Microsoft Edge WebView2 Runtime missing?)")
		return nil, nil, false
	}
	hwnd := uintptr(w.Window())
	darkTitleBar(hwnd)
	w.SetSize(int(winW*scale), int(winH*scale), webview2.HintFixed)
	centreWindow(hwnd)

	var (
		mu         sync.Mutex
		game       *exec.Cmd
		done       func()
		busy       bool // starting the game, or installing
		upd        *onlineUpdate
		selfMinded bool // (the game runs with the launcher open, which minds it: nothing for main to do)
	)
	var windowGone atomic.Bool // (after Terminate nothing runs what's dispatched)
	eval := func(fn string, args ...any) {
		if windowGone.Load() {
			return
		}
		parts := make([]string, len(args))
		for i, a := range args {
			b, _ := json.Marshal(a)
			parts[i] = string(b)
		}
		js := fmt.Sprintf("window.%s && window.%s(%s)", fn, fn, strings.Join(parts, ","))
		w.Dispatch(func() { w.Eval(js) })
	}
	take := func() bool {
		mu.Lock()
		defer mu.Unlock()
		if busy {
			return false
		}
		busy = true
		return true
	}
	release := func() { mu.Lock(); busy = false; mu.Unlock() }
	exe, _ := os.Executable()
	cfg := loadLauncherConfig()
	// the program to start for the next launch: this one, or the launcher it was installed as
	restartWith := func(path string, args ...string) {
		next := exec.Command(path, args...)
		next.Dir = filepath.Dir(path)
		if err := next.Start(); err != nil {
			logf("launcher: starting %s: %v", path, err)
			eval("onToast", "Couldn't start "+path+": "+err.Error(), "err")
			return
		}
		w.Dispatch(func() { hideWindow(hwnd); w.Terminate() })
	}
	gameDir := func(id string) string {
		if p, ok := l.dirs[id]; ok && p != nil {
			return *p
		}
		return ""
	}

	// the games' own icons (exeicon_windows.go), read once per program
	icons := map[string]string{}
	gameIcon := func(id, dir string) string {
		exe := gameExe(id, dir)
		if dir == "" || exe == "" {
			return ""
		}
		if v, ok := icons[exe]; ok {
			return v
		}
		v := ""
		if b, err := exeIconPNG(exe, 64); err == nil {
			v = "data:image/png;base64," + base64.StdEncoding.EncodeToString(b)
		} else {
			logf("icon of %s: %v", exe, err)
		}
		icons[exe] = v
		return v
	}

	w.Bind("vh_state", func() map[string]any {
		games := []map[string]any{{"id": "etterna", "name": "Etterna", "path": l.etterna, "found": l.etterna != "",
			"required": true, "fixed": !l.standalone, "icon": gameIcon("etterna", l.etterna),
			"what": "The game VSRG Hub runs in: its engine, your scores, profiles and Etterna packs."}}
		for _, g := range Games {
			if g.ID == "etterna" {
				continue
			}
			d := gameDir(g.ID)
			what := map[string]string{
				"osu":      "Your osu!mania songs, your skins (notes, interface, cursor) and collections.",
				"quaver":   "Your Quaver songs and skins.",
				"qwilight": "Your Qwilight songs.",
			}[g.ID]
			note := ""
			if g.ID == "osu" && d == "" && dirExists(filepath.Join(os.Getenv("APPDATA"), "osu", "files")) {
				note = "Only osu!lazer is here: VSRG Hub reads osu!stable's Songs folder."
			}
			games = append(games, map[string]any{"id": g.ID, "name": g.Name, "path": d, "found": d != "" && dirExists(d), "what": what, "note": note, "icon": gameIcon(g.ID, d)})
		}
		st := map[string]any{
			"version":    version,
			"standalone": l.standalone,
			"exe":        exe,
			"placed":     !l.standalone || strings.EqualFold(filepath.Clean(cfg.Launcher), filepath.Clean(exe)),
			"etterna":    l.etterna,
			"installed":  "",
			"games":      games,
			"shortcut":   desktopShortcutExists(),
			"changelog":  builtinChangelog(),
			"installDir": filepath.Join(os.Getenv("LOCALAPPDATA"), "Programs", "VSRG Hub"),
			"feed":       updateManifestURL(l.home, l.data) != "",
		}
		if l.etterna != "" {
			st["installed"] = installedVersion(l.home)
			st["theme"] = pickedTheme(filepath.Join(l.home, "Root"), l.etterna)
			st["themes"] = availableThemes(l.etterna, l.home)
			st["options"] = launcherOptions(l.etterna)
			st["discord"] = map[string]any{"on": !loadState(l.data).DiscordOff, "ready": discordAppID != ""}
			st["keepOpen"] = loadState(l.data).KeepOpen
			st["notices"] = !loadState(l.data).NoticesOff
		}
		sizes, rates, cur, curRate := displayModes()
		st["displays"] = map[string]any{"sizes": sizes, "rates": rates, "current": cur, "currentRate": curRate}
		return st
	})
	w.Bind("vh_pick", func(theme string) {
		if l.etterna == "" {
			return
		}
		for _, t := range availableThemes(l.etterna, l.home) {
			if t == theme {
				if err := setPickedTheme(l.data, theme); err != nil {
					logf("launcher: saving the look: %v", err)
				}
				logf("launcher: look %s", theme)
			}
		}
	})
	// a game's folder, picked in Windows' folder dialog. "" when it was taken, else why not
	// ("restart": the launcher starts again with the new Etterna)
	w.Bind("vh_pickGame", func(id string) string {
		mu.Lock()
		b := busy
		mu.Unlock()
		if b {
			return "Wait until VSRG Hub has finished what it's doing."
		}
		title := map[string]string{"etterna": "Where is Etterna? (the folder with Program\\Etterna.exe)", "osu": "Where is osu!? (the folder with osu!.exe)",
			"quaver": "Where is Quaver? (the folder with Quaver.exe)", "qwilight": "Where is Qwilight? (the folder with Qwilight.exe)"}[id]
		start := gameDir(id)
		if id == "etterna" {
			start = l.etterna
		}
		if start == "" {
			start = `C:\`
		}
		d := pickPath(hwnd, title, start, true, "", "")
		if d == "" {
			return "cancel"
		}
		if id == "etterna" {
			e := etternaFromPick(d)
			if e == "" {
				return "There's no Etterna in that folder (Program\\Etterna.exe wasn't found)."
			}
			c := loadLauncherConfig()
			c.Etterna = e
			saveLauncherConfig(c)
			logf("launcher: Etterna is at %s", e)
			go restartWith(exe)
			return "restart"
		}
		got, ok := checkGameDir(id, d)
		if !ok {
			return got
		}
		if p, ok := l.dirs[id]; ok {
			*p = got
		}
		if l.data != "" {
			known := loadKnownDirs(l.data)
			known[id] = got
			saveKnownDirs(l.data, known)
		}
		logf("launcher: %s is at %s", id, got)
		return ""
	})
	w.Bind("vh_forgetGame", func(id string) {
		if id == "etterna" {
			return
		}
		if p, ok := l.dirs[id]; ok {
			*p = ""
		}
		if l.data != "" {
			known := loadKnownDirs(l.data)
			delete(known, id)
			saveKnownDirs(l.data, known)
		}
	})
	w.Bind("vh_setKeepOpen", func(on bool) {
		if l.data == "" {
			return
		}
		st := loadState(l.data)
		st.KeepOpen = on
		saveState(l.data, st)
	})
	w.Bind("vh_setNotices", func(on bool) {
		if l.data == "" {
			return
		}
		st := loadState(l.data)
		st.NoticesOff = !on
		saveState(l.data, st)
		if !on {
			eval("onOnline", map[string]any{"kind": "notices", "list": []notice{}})
		}
	})
	w.Bind("vh_setDiscord", func(on bool) {
		if l.data == "" {
			return
		}
		st := loadState(l.data)
		st.DiscordOff = !on
		saveState(l.data, st)
	})
	w.Bind("vh_setOption", func(key string, value any) string {
		if l.etterna == "" {
			return "Etterna isn't set up yet."
		}
		if err := setLauncherOption(l.etterna, key, value); err != nil {
			logf("launcher: option %s: %v", key, err)
			return err.Error()
		}
		logf("launcher: %s = %v", key, value)
		return ""
	})
	w.Bind("vh_play", func() {
		if l.etterna == "" || !take() {
			return
		}
		if l.standalone {
			if v := installedVersion(l.home); v == "" {
				release()
				eval("onStatus", "VSRG Hub isn't installed yet.", "err")
				return
			}
		}
		go func() {
			cmd, d, err := l.start(func(step string) { eval("onStatus", step, "busy") })
			if err != nil {
				logf("launcher: %v", err)
				release()
				eval("onStatus", "Couldn't start the game: "+err.Error(), "err")
				return
			}
			// (your new osu! / Quaver plays, for the game to rate once it's up)
			if l.importNew != nil {
				l.importNew()
			}
			if l.data != "" && loadState(l.data).KeepOpen {
				// the launcher stays: it minds the game itself (scores sent, rankings answered, the
				// tray icon, Discord) and is ready again once the game ends
				stopOnline := startOnlineService(l.data)
				stopTray := startTray(func() string { return trayTip(l.data) })
				stopPresence := startPresence(l.data, true)
				eval("onStatus", "The game is running", "busy", "The launcher stays open; play again when the game closes.")
				eval("onGame", true)
				mu.Lock()
				game, done, selfMinded = cmd, nil, true
				mu.Unlock()
				cmd.Wait()
				stopPresence()
				stopTray()
				stopOnline()
				d()
				logf("Etterna exited")
				mu.Lock()
				game, selfMinded = nil, false
				mu.Unlock()
				release()
				eval("onGame", false)
				eval("onStatus", "Ready to play", "ok", "")
				eval("onAccountRefresh")
				return
			}
			mu.Lock()
			game, done = cmd, d
			mu.Unlock()
			// the launcher goes away once the game is up
			windowGone.Store(true)
			w.Dispatch(func() { hideWindow(hwnd); w.Terminate() })
		}()
	})
	// VSRG Hub online (online.go): each call answers in window.onOnline({kind, ...})
	accountState := func() map[string]any {
		s, err := onlineToken()
		if err != nil || s == nil {
			st := map[string]any{"kind": "account", "signedIn": false}
			if err != nil && err == errOffline && loadSession() != nil {
				st["offline"] = true
			}
			return st
		}
		st := map[string]any{"kind": "account", "signedIn": true, "email": s.Email, "username": s.Username, "userId": s.UserID, "waiting": outboxCount(l.data)}
		if v := onlineServerVersion(); v >= 0 && v < wantServerVersion {
			st["serverBehind"] = v
			st["serverWant"] = wantServerVersion
		}
		if s.Username != "" {
			st["ratings"] = onlineMyRatings(s)
			st["admin"] = onlineIsAdmin(s)
			var motd string
			if onlineCall("POST", "/rest/v1/rpc/motd", map[string]any{}, "", &motd) == nil {
				st["motd"] = motd
			}
			st["picture"] = myPicture(s)
			if l.data != "" {
				if b, err := os.ReadFile(filepath.Join(onlineDir(l.data), "backfill.txt")); err == nil {
					st["backfill"] = strings.TrimSpace(string(b))
				}
				// the osu! plays: handed to the game (jobs.txt), rated by it (done.txt)
				if _, err := os.Stat(filepath.Join(onlineDir(l.data), "osu", "jobs.txt")); err == nil {
					st["osu"] = "want"
					if b, err := os.ReadFile(filepath.Join(onlineDir(l.data), "osu", "done.txt")); err == nil {
						st["osu"] = strings.TrimSpace(string(b))
					}
				}
			}
		}
		return st
	}
	onlineDo := func(f func() error) {
		go func() {
			if err := f(); err != nil {
				eval("onOnline", map[string]any{"kind": "error", "error": err.Error()})
				return
			}
			eval("onOnline", accountState())
			if l.data != "" {
				go sendOutbox(l.data)
			}
		}()
	}
	w.Bind("vh_account", func() { go func() { eval("onOnline", accountState()) }() })
	// the Online page's extras (online.go, avatar.go)
	w.Bind("vh_activity", func(keys int) {
		go func() {
			rows, err := onlineActivity(keys)
			ev := map[string]any{"kind": "activity", "rows": rows, "keys": keys}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	// ranking notices (notices.go): the kept ones now, the rankings looked at again after
	w.Bind("vh_notices", func() {
		go func() {
			eval("onOnline", map[string]any{"kind": "notices", "list": noticeList(l.data)})
			if fresh := checkNotices(l.data, false); len(fresh) > 0 {
				eval("onOnline", map[string]any{"kind": "notices", "list": noticeList(l.data), "fresh": fresh})
			}
		}()
	})
	// the daily challenge (daily.go)
	w.Bind("vh_daily", func(keys int) {
		go func() {
			d, err := onlineDaily(keys)
			ev := map[string]any{"kind": "daily", "keys": keys, "daily": d}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_dailyPlay", func(chart string) bool {
		if l.data == "" {
			return false
		}
		writeJump(l.data, chart)
		mu.Lock()
		running := game != nil
		mu.Unlock()
		return running
	})
	w.Bind("vh_bestPlays", func(keys int) {
		go func() {
			rows, err := onlineBestPlays(keys)
			ev := map[string]any{"kind": "best", "rows": rows, "keys": keys}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_playsOfTheDay", func(keys int) {
		go func() {
			rows, err := onlinePlaysOfTheDay(keys)
			ev := map[string]any{"kind": "potd", "rows": rows, "keys": keys}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_chart", func(chart string, title string) {
		go func() {
			rows, err := onlineChart(chart, 0)
			ev := map[string]any{"kind": "chart", "chart": chart, "title": title, "rows": rows}
			if s, err := onlineToken(); err == nil {
				ev["me"] = s.UserID
				ev["pins"] = myPins(s)
			}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_history", func(id string, keys int) {
		go func() {
			pts, err := onlineHistory(id, keys)
			ev := map[string]any{"kind": "history", "id": id, "keys": keys, "points": pts}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_playerTop", func(id string, keys int, source string) {
		go func() {
			rows, err := onlineTopBySource(id, keys, source)
			ev := map[string]any{"kind": "playerTop", "id": id, "keys": keys, "source": source, "rows": rows}
			if err != nil {
				ev["error"] = err.Error()
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_findPlayers", func(q string) {
		go func() {
			rows, _ := onlineFindPlayers(q)
			eval("onOnline", map[string]any{"kind": "players", "q": strings.ToLower(strings.TrimSpace(q)), "rows": rows})
		}()
	})
	w.Bind("vh_pin", func(id float64, pin bool) {
		go func() {
			if err := onlinePin(int64(id), pin); err != nil {
				eval("onOnline", map[string]any{"kind": "toast", "text": err.Error(), "bad": true})
				return
			}
			eval("onOnline", map[string]any{"kind": "pinned", "id": int64(id), "pin": pin})
		}()
	})
	w.Bind("vh_reorderPins", func(ids []any) {
		go func() {
			var out []int64
			for _, v := range ids {
				if f, ok := v.(float64); ok {
					out = append(out, int64(f))
				}
			}
			if err := onlineReorderPins(out); err != nil {
				eval("onOnline", map[string]any{"kind": "toast", "text": err.Error(), "bad": true})
			}
		}()
	})
	w.Bind("vh_setPicture", func(remove bool) {
		go func() {
			var err error
			if remove {
				err = onlineRemoveAvatar()
			} else {
				home, _ := os.UserHomeDir()
				p := pickPath(hwnd, "Pick your profile picture", filepath.Join(home, "Pictures"), false, "Pictures", "*.png;*.jpg;*.jpeg;*.gif;*.webp")
				if p == "" {
					return
				}
				_, err = onlineSetAvatar(p)
			}
			if err != nil {
				eval("onOnline", map[string]any{"kind": "toast", "text": err.Error(), "bad": true})
				return
			}
			eval("onOnline", accountState())
			eval("onOnline", map[string]any{"kind": "picture"})
		}()
	})
	// a player's profile (clicked on the rankings)
	w.Bind("vh_player", func(id string) {
		go func() {
			p, err := onlinePlayer(id)
			if err != nil {
				eval("onOnline", map[string]any{"kind": "player", "id": id, "error": err.Error()})
				return
			}
			me, admin := "", false
			if s, err := onlineToken(); err == nil {
				me, admin = s.UserID, onlineIsAdmin(s)
			}
			eval("onOnline", map[string]any{"kind": "player", "id": id, "player": p, "me": me, "admin": admin})
		}()
	})
	// your older plays: the game gets them ready the next time song select comes up (backfill.txt)
	w.Bind("vh_backfill", func() {
		if l.data == "" {
			return
		}
		os.MkdirAll(onlineDir(l.data), 0o755)
		os.WriteFile(filepath.Join(onlineDir(l.data), "backfill.txt"), []byte("want\n"), 0o644)
		go func() { eval("onOnline", accountState()) }()
	})
	// admins
	w.Bind("vh_adminScore", func(id float64, remove bool, player string) {
		go func() {
			if err := onlineAdmin("admin_remove_score", map[string]any{"score": int64(id), "remove": remove}, nil); err != nil {
				eval("onOnline", map[string]any{"kind": "toast", "error": err.Error()})
				return
			}
			eval("onOnline", map[string]any{"kind": "toast", "text": map[bool]string{true: "Score taken off the rankings", false: "Score back on the rankings"}[remove]})
			if p, err := onlinePlayer(player); err == nil {
				eval("onOnline", map[string]any{"kind": "player", "id": player, "player": p, "me": "", "admin": true})
			}
		}()
	})
	w.Bind("vh_adminBan", func(player string, ban bool) {
		go func() {
			if err := onlineAdmin("admin_ban", map[string]any{"player": player, "ban": ban}, nil); err != nil {
				eval("onOnline", map[string]any{"kind": "toast", "error": err.Error()})
				return
			}
			eval("onOnline", map[string]any{"kind": "toast", "text": map[bool]string{true: "Player banned", false: "Player unbanned"}[ban]})
			if p, err := onlinePlayer(player); err == nil {
				eval("onOnline", map[string]any{"kind": "player", "id": player, "player": p, "me": "", "admin": true})
			}
		}()
	})
	// the Admin page: any admin function, its answer back as an "admin" event
	w.Bind("vh_admin", func(fn string, args map[string]any) {
		go func() {
			var out any
			ev := map[string]any{"kind": "admin", "fn": fn, "args": args}
			if err := onlineAdmin(fn, args, &out); err != nil {
				ev["error"] = err.Error()
			} else {
				ev["data"] = out
			}
			eval("onOnline", ev)
		}()
	})
	w.Bind("vh_adminSuspicious", func() {
		go func() {
			var rows []map[string]any
			if err := onlineAdmin("admin_suspicious", map[string]any{"max_rows": 100}, &rows); err != nil {
				eval("onOnline", map[string]any{"kind": "suspicious", "error": err.Error()})
				return
			}
			eval("onOnline", map[string]any{"kind": "suspicious", "rows": rows})
		}()
	})
	// (the scores waiting in the outbox, sent now)
	w.Bind("vh_sendScores", func() {
		go func() {
			sendOutbox(l.data)
			st := accountState()
			if n := outboxCount(l.data); n > 0 && lastOutboxNote != "" {
				st["note"] = lastOutboxNote
			}
			eval("onOnline", st)
		}()
	})
	w.Bind("vh_signIn", func(email, password string) {
		onlineDo(func() error { return onlineSignIn(strings.TrimSpace(email), password) })
	})
	w.Bind("vh_signUp", func(email, password string) {
		go func() {
			confirm, err := onlineSignUp(strings.TrimSpace(email), password)
			if err != nil {
				eval("onOnline", map[string]any{"kind": "error", "error": err.Error()})
				return
			}
			if confirm {
				eval("onOnline", map[string]any{"kind": "confirm", "email": strings.TrimSpace(email)})
				return
			}
			eval("onOnline", accountState())
		}()
	})
	w.Bind("vh_setName", func(name string) { onlineDo(func() error { return onlineCreateProfile(name) }) })
	w.Bind("vh_signOut", func() { onlineDo(func() error { onlineSignOut(); return nil }) })
	w.Bind("vh_resetPassword", func(email string) {
		go func() {
			if err := onlineResetPassword(strings.TrimSpace(email)); err != nil {
				eval("onOnline", map[string]any{"kind": "error", "error": err.Error()})
				return
			}
			eval("onOnline", map[string]any{"kind": "reset", "email": strings.TrimSpace(email)})
		}()
	})
	w.Bind("vh_rankings", func(keys int, skill string) {
		go func() {
			var rows []rankingRow
			var err error
			if skill == "month" {
				rows, err = onlineRankingsMonth(keys)
			} else {
				rows, err = onlineRankings(keys, skill, 100, 0)
			}
			if err != nil {
				eval("onOnline", map[string]any{"kind": "rankings", "keys": keys, "skill": skill, "error": err.Error()})
				return
			}
			me := ""
			if s := loadSession(); s != nil {
				me = s.UserID
			}
			eval("onOnline", map[string]any{"kind": "rankings", "keys": keys, "skill": skill, "rows": rows, "me": me})
		}()
	})
	if l.data != "" {
		go sendOutbox(l.data)
	}
	w.Bind("vh_check", func() {
		go func() {
			url := updateManifestURL(l.home, l.data)
			if url == "" {
				eval("onFeed", map[string]any{"state": "nofeed"})
				return
			}
			f, err := readFeed(url)
			if err != nil || f.Latest == nil {
				if err == nil {
					err = fmt.Errorf("no version in it")
				}
				logf("update check: %v", err)
				eval("onFeed", map[string]any{"state": "offline"})
				return
			}
			u := *f.Latest
			installed := ""
			if l.etterna != "" {
				installed = installedVersion(l.home)
			}
			ok := u.Version != "" && strings.HasPrefix(u.URL, "https://") && len(u.SHA256) == 64
			mu.Lock()
			if ok {
				upd = &u
			}
			mu.Unlock()
			newer := ok && (newerVersion(u.Version, version) || (l.etterna != "" && (installed == "" || installed == "?" || newerVersion(u.Version, installed))))
			if newer {
				logf("update check: %s is out", u.Version)
			}
			eval("onFeed", map[string]any{"state": "ok", "latest": u.Version, "notes": u.Notes, "newer": newer, "changelog": f.Changelog})
		}()
	})
	// after VSRG Hub's files were put in Etterna's VSRGHub folder: the launcher starts again as the
	// new version (the folder's own vsrghub.exe, or this launcher updated from it)
	afterInstall := func(v string) {
		newExe := filepath.Join(l.home, "vsrghub.exe")
		if !l.standalone {
			logf("update: installed %s; restarting the launcher", v)
			restartWith(newExe)
			return
		}
		// (the launcher installed on its own, when it was just put somewhere: that one is updated and
		// started; else this one)
		target := exe
		if c := loadLauncherConfig(); c.Launcher != "" && fileExists(c.Launcher) {
			target = c.Launcher
		}
		if strings.EqualFold(filepath.Clean(target), filepath.Clean(exe)) {
			if self, err := replaceSelf(newExe); err == nil {
				logf("update: installed %s; the launcher is now that version", v)
				restartWith(self)
				return
			} else {
				logf("update: updating the launcher: %v", err)
			}
		} else if err := copyFile(newExe, target); err != nil {
			logf("update: updating the launcher at %s: %v", target, err)
		}
		restartWith(target)
	}
	install := func(z updateZip) error {
		if l.etterna == "" {
			return fmt.Errorf("Etterna isn't set up")
		}
		os.MkdirAll(l.home, 0o755)
		eval("onProgress", map[string]any{"pct": 100, "text": "Installing " + z.version + "..."})
		if err := installZip(z, l.home, l.data); err != nil {
			return err
		}
		// (the launcher's own desktop shortcut stays: the VSRGHub folder's copy won't make another)
		if l.standalone {
			os.WriteFile(filepath.Join(l.data, "desktop-shortcut.txt"), []byte("the launcher is installed on its own\n"), 0o644)
		}
		return nil
	}
	w.Bind("vh_update", func() {
		mu.Lock()
		u := upd
		mu.Unlock()
		if u == nil || !take() {
			return
		}
		go func() {
			fail := func(err error) {
				release()
				logf("update: %v", err)
				eval("onProgress", map[string]any{"error": "Didn't work: " + err.Error()})
			}
			path, err := downloadUpdate(*u, filepath.Join(launcherDir(), "updates"), func(got, total int64) {
				pct := 0
				if total > 0 {
					pct = int(got * 100 / total)
				}
				eval("onProgress", map[string]any{"pct": pct, "text": fmt.Sprintf("Downloading %s... %.1f MB", u.Version, float64(got)/(1<<20))})
			})
			if err != nil {
				fail(err)
				return
			}
			z, ok := readUpdateZip(path)
			if !ok {
				fail(fmt.Errorf("the downloaded file isn't a VSRG Hub zip"))
				return
			}
			if err := install(z); err != nil {
				fail(err)
				return
			}
			afterInstall(z.version)
		}()
	})
	w.Bind("vh_installZip", func() string {
		if l.etterna == "" {
			return "Etterna isn't set up yet."
		}
		home := os.Getenv("USERPROFILE")
		p := pickPath(hwnd, "Pick a VSRG Hub zip (VSRGHub-....zip)", filepath.Join(home, "Downloads"), false, "VSRG Hub zip", "*.zip")
		if p == "" {
			return "cancel"
		}
		z, ok := readUpdateZip(p)
		if !ok {
			return "That zip isn't VSRG Hub (it has no vsrghub.exe)."
		}
		if !take() {
			return "Wait until VSRG Hub has finished what it's doing."
		}
		go func() {
			if err := install(z); err != nil {
				release()
				logf("update: %v", err)
				eval("onProgress", map[string]any{"error": "Didn't work: " + err.Error()})
				return
			}
			afterInstall(z.version)
		}()
		return ""
	})
	// Install the launcher: this program copied to dir as "VSRG Hub.exe", with shortcuts
	w.Bind("vh_placeLauncher", func(dir string, desktop, startMenu, restart bool) string {
		if dir == "" {
			dir = filepath.Join(os.Getenv("LOCALAPPDATA"), "Programs", "VSRG Hub")
		}
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err.Error()
		}
		dst := filepath.Join(dir, "VSRG Hub.exe")
		if !strings.EqualFold(filepath.Clean(dst), filepath.Clean(exe)) {
			if err := copyFile(exe, dst); err != nil {
				return "Couldn't copy the launcher there: " + err.Error()
			}
		}
		if desktop {
			if err := makeShortcut(filepath.Join(desktopDir(), "VSRG Hub.lnk"), dst, dir); err != nil {
				logf("launcher: desktop shortcut: %v", err)
			}
		}
		if startMenu {
			if err := makeShortcut(filepath.Join(startMenuDir(), "VSRG Hub.lnk"), dst, dir); err != nil {
				logf("launcher: Start menu shortcut: %v", err)
			}
		}
		c := loadLauncherConfig()
		c.Launcher = dst
		if l.etterna != "" {
			c.Etterna = l.etterna
		}
		saveLauncherConfig(c)
		if l.data != "" {
			os.WriteFile(filepath.Join(l.data, "desktop-shortcut.txt"), []byte("the launcher is installed on its own\n"), 0o644)
		}
		logf("launcher: installed at %s (desktop %v, Start menu %v)", dst, desktop, startMenu)
		if restart && !strings.EqualFold(filepath.Clean(dst), filepath.Clean(exe)) {
			go restartWith(dst)
		}
		return ""
	})
	// the launcher stays where it is (no copy anywhere)
	w.Bind("vh_keepHere", func() {
		c := loadLauncherConfig()
		c.Launcher = exe
		if l.etterna != "" {
			c.Etterna = l.etterna
		}
		saveLauncherConfig(c)
		cfg = c
	})
	w.Bind("vh_pickDir", func(start string) string {
		return pickPath(hwnd, "Where should the launcher go?", start, true, "", "")
	})
	w.Bind("vh_open", func(what string) {
		switch {
		case what == "hub" && l.home != "":
			openFolder(l.home)
		case what == "etterna" && l.etterna != "":
			openFolder(l.etterna)
		case what == "launcher":
			openFolder(filepath.Dir(exe))
		case what == "log":
			if l.standalone {
				openFolder(launcherDir())
			} else if l.home != "" {
				openFolder(l.home)
			}
		case strings.HasPrefix(what, "game:"):
			if d := gameDir(strings.TrimPrefix(what, "game:")); d != "" {
				openFolder(d)
			}
		case strings.HasPrefix(what, "https://"):
			openURL(what)
		}
	})
	// your osu! plays: read, judged and handed to the game (osureplay.go)
	// your osu! / Quaver plays: all of them again, or only the new ones (osureplay.go); quiet: on
	// its own (at start and when the game starts), told only when there is something to tell
	importReplays := func(onlyNew, quiet bool) {
		if l.data == "" {
			if !quiet {
				eval("onOnline", map[string]any{"kind": "osu", "error": "VSRG Hub isn't installed yet"})
			}
			return
		}
		if quiet {
			if s, err := onlineToken(); err != nil || s.Username == "" {
				return
			}
			if _, err := os.Stat(filepath.Join(l.data, "Library", "triwheel-cache.json")); err != nil {
				return
			}
		}
		if !importMu.TryLock() {
			return
		}
		defer importMu.Unlock()
		osuDir, quaverDir := "", ""
		if d := l.dirs["osu"]; d != nil {
			osuDir = *d
		}
		if d := l.dirs["quaver"]; d != nil {
			quaverDir = *d
		}
		if osuDir == "" && quaverDir == "" && quiet {
			return
		}
		rep := importOsuReplays(filepath.Join(l.data, "Library"), osuDir, quaverDir, l.data, onlyNew, func(s string) {
			if !quiet {
				eval("onOnline", map[string]any{"kind": "osu", "progress": s})
			}
		})
		if quiet {
			if rep.Jobs > 0 {
				eval("onOnline", map[string]any{"kind": "toast", "text": fmt.Sprintf("%d new osu! / Quaver play%s: rated and sent the next time song select comes up in the game", rep.Jobs, plural(rep.Jobs))})
				eval("onOnline", accountState())
			}
			return
		}
		eval("onOnline", map[string]any{"kind": "osu", "report": rep})
		eval("onOnline", accountState())
	}
	l.importNew = func() { go importReplays(true, true) }
	w.Bind("vh_osuImport", func() { go importReplays(false, false) })
	w.Bind("vh_osuImportNew", func() { go importReplays(true, false) })
	// "Report a problem": a zip of the logs on the desktop, shown in Explorer (report.go)
	// your scores as a CSV on the desktop
	w.Bind("vh_exportScores", func() {
		go func() {
			desk, _ := windows.KnownFolderPath(windows.FOLDERID_Desktop, 0)
			p, err := exportScoresCSV(desk)
			if err != nil {
				eval("onOnline", map[string]any{"kind": "toast", "error": err.Error()})
				return
			}
			eval("onOnline", map[string]any{"kind": "toast", "text": "Saved to your desktop: " + filepath.Base(p)})
		}()
	})
	w.Bind("vh_report", func(text string) {
		go func() {
			desk, _ := windows.KnownFolderPath(windows.FOLDERID_Desktop, 0)
			p, err := buildReport(desk, text, l.etterna, l.home, l.data)
			if err != nil {
				eval("onReport", map[string]any{"error": err.Error()})
				return
			}
			logf("report: %s", p)
			exec.Command("explorer.exe", "/select,"+p).Start()
			eval("onReport", map[string]any{"path": p})
		}()
	})
	w.Bind("vh_shortcut", func() bool {
		target, wd := filepath.Join(l.home, "vsrghub.exe"), l.home
		if l.standalone {
			target, wd = exe, filepath.Dir(exe)
		}
		if err := makeShortcut(filepath.Join(desktopDir(), "VSRG Hub.lnk"), target, wd); err != nil {
			logf("launcher: desktop shortcut: %v", err)
			return false
		}
		return true
	})

	if !l.standalone && l.data != "" {
		// the first time the launcher opens: a desktop shortcut to it, so the game is one click away
		marker := filepath.Join(l.data, "desktop-shortcut.txt")
		if _, err := os.Stat(marker); err != nil {
			if !desktopShortcutExists() {
				if err := makeDesktopShortcut(filepath.Join(l.home, "vsrghub.exe"), l.home); err != nil {
					logf("launcher: desktop shortcut: %v", err)
				} else {
					logf("launcher: made a desktop shortcut")
				}
			}
			os.WriteFile(marker, []byte("made once by the launcher; delete the shortcut if you don't want it\n"), 0o644)
		}
	}

	// a new icon: Windows keeps showing the old picture for the desktop shortcut (its icon cache)
	// until told, so the shortcut is saved again (to where it pointed) and the shell told that icons
	// changed, once per icon
	iconMark := filepath.Join(launcherDir(), "icon-version.txt")
	if b, _ := os.ReadFile(iconMark); strings.TrimSpace(string(b)) != iconVersion {
		lnk := filepath.Join(desktopDir(), "VSRG Hub.lnk")
		if desktopShortcutExists() {
			if t := shortcutTarget(lnk); t != "" && fileExists(t) {
				if err := makeShortcut(lnk, t, filepath.Dir(t)); err != nil {
					logf("launcher: desktop shortcut: %v", err)
				}
			}
		}
		refreshShellIcons(lnk)
		os.WriteFile(iconMark, []byte(iconVersion+"\n"), 0o644)
		logf("launcher: told Windows the icon changed")
	}

	html := strings.ReplaceAll(launcherHTML, "{{ICON}}", "data:image/png;base64,"+base64.StdEncoding.EncodeToString(launcherIcon))
	w.SetHtml(html)
	if l.data != "" {
		go writeMe(l.data) // (your place on the rankings, for the Discord presence)
	}
	if l.importNew != nil {
		l.importNew() // (osu! / Quaver plays made since the last look)
	}
	stopPresence := startPresence(l.data, false)
	w.Run()
	stopPresence()
	// (gone at once: nothing handles the window's messages after this, so it would hang about grey)
	hideWindow(hwnd)
	windows.NewLazySystemDLL("user32.dll").NewProc("DestroyWindow").Call(hwnd)

	mu.Lock()
	defer mu.Unlock()
	if selfMinded && game != nil {
		// (the window closed with the game running: the goroutine above sees the game out)
		g := game
		return nil, func() { g.Wait() }, true
	}
	return game, done, true
}

// dpiScale: the screen's scale (1 at 100%, 1.5 at 150%), so the window is the same size on every screen.
func dpiScale() float64 {
	user32 := windows.NewLazySystemDLL("user32.dll")
	if p := user32.NewProc("GetDpiForSystem"); p.Find() == nil {
		if dpi, _, _ := p.Call(); dpi > 0 {
			return float64(dpi) / 96
		}
	}
	return 1
}

// darkTitleBar asks Windows for the dark title bar (Windows 10 2004 and later; ignored before).
func darkTitleBar(hwnd uintptr) {
	dwm := windows.NewLazySystemDLL("dwmapi.dll")
	p := dwm.NewProc("DwmSetWindowAttribute")
	if p.Find() != nil {
		return
	}
	on := int32(1)
	for _, attr := range []uintptr{20, 19} { // DWMWA_USE_IMMERSIVE_DARK_MODE (and its old number)
		if r, _, _ := p.Call(hwnd, attr, uintptr(unsafe.Pointer(&on)), 4); r == 0 {
			break
		}
	}
	// a caption colour to match the launcher (Windows 11)
	col := uint32(0x00140A0C) // COLORREF 0x00BBGGRR: #0c0a14
	p.Call(hwnd, 35, uintptr(unsafe.Pointer(&col)), 4)
}

func desktopDir() string {
	if d, err := windows.KnownFolderPath(windows.FOLDERID_Desktop, 0); err == nil && d != "" {
		return d
	}
	return filepath.Join(os.Getenv("USERPROFILE"), "Desktop")
}

// iconVersion names the icon in use (media/icon, tools/makeicon.py): a new name makes the launcher
// refresh the desktop shortcut's picture once.
const iconVersion = "arrows-2"

// refreshShellIcons tells Explorer that a file's picture and the icons in general changed, so it
// draws them again instead of the ones it has kept.
func refreshShellIcons(path string) {
	shell32 := windows.NewLazySystemDLL("shell32.dll")
	notify := shell32.NewProc("SHChangeNotify")
	if p, err := windows.UTF16PtrFromString(path); err == nil {
		notify.Call(0x00002000, 0x0005|0x1000, uintptr(unsafe.Pointer(p)), 0) // SHCNE_UPDATEITEM, SHCNF_PATHW|SHCNF_FLUSHNOWAIT
	}
	notify.Call(0x08000000, 0x0000|0x1000, 0, 0) // SHCNE_ASSOCCHANGED, SHCNF_IDLIST|SHCNF_FLUSHNOWAIT
}

func desktopShortcutExists() bool {
	_, err := os.Stat(filepath.Join(desktopDir(), "VSRG Hub.lnk"))
	return err == nil
}

// makeDesktopShortcut puts "VSRG Hub" on the desktop: a Windows shortcut made through the shell's
// own ShellLink object (no script).
func makeDesktopShortcut(target, workDir string) error {
	errc := make(chan error, 1)
	go func() {
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		errc <- shellLink(filepath.Join(desktopDir(), "VSRG Hub.lnk"), target, workDir)
	}()
	if err := <-errc; err != nil {
		return err
	}
	if !desktopShortcutExists() {
		return fmt.Errorf("the shortcut wasn't made")
	}
	return nil
}

var (
	clsidShellLink  = windows.GUID{Data1: 0x00021401, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	iidIShellLinkW  = windows.GUID{Data1: 0x000214F9, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	iidIPersistFile = windows.GUID{Data1: 0x0000010B, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
)

// comCall calls method n of a COM object (its vtable's nth entry).
func comCall(obj uintptr, n int, args ...uintptr) uintptr {
	o := *(*unsafe.Pointer)(unsafe.Pointer(&obj))
	vtbl := *(*unsafe.Pointer)(o)
	fn := *(*uintptr)(unsafe.Add(vtbl, n*int(unsafe.Sizeof(uintptr(0)))))
	r, _, _ := syscall.SyscallN(fn, append([]uintptr{obj}, args...)...)
	return r
}

func shellLink(lnk, target, workDir string) error {
	ole := windows.NewLazySystemDLL("ole32.dll")
	ole.NewProc("CoInitializeEx").Call(0, 2) // COINIT_APARTMENTTHREADED (already set up is fine)
	defer ole.NewProc("CoUninitialize").Call()
	var link uintptr
	if hr, _, _ := ole.NewProc("CoCreateInstance").Call(uintptr(unsafe.Pointer(&clsidShellLink)), 0, 1, // CLSCTX_INPROC_SERVER
		uintptr(unsafe.Pointer(&iidIShellLinkW)), uintptr(unsafe.Pointer(&link))); hr != 0 || link == 0 {
		return fmt.Errorf("ShellLink: 0x%X", hr)
	}
	defer comCall(link, 2) // Release
	var keep []*uint16
	str := func(s string) uintptr {
		p, _ := windows.UTF16PtrFromString(s)
		keep = append(keep, p)
		return uintptr(unsafe.Pointer(p))
	}
	defer runtime.KeepAlive(&keep)
	comCall(link, 20, str(target))    // SetPath
	comCall(link, 9, str(workDir))    // SetWorkingDirectory
	comCall(link, 7, str("VSRG Hub")) // SetDescription
	comCall(link, 17, str(target), 0) // SetIconLocation
	var pf uintptr
	if hr := comCall(link, 0, uintptr(unsafe.Pointer(&iidIPersistFile)), uintptr(unsafe.Pointer(&pf))); hr != 0 || pf == 0 {
		return fmt.Errorf("IPersistFile: 0x%X", hr)
	}
	defer comCall(pf, 2)
	if hr := comCall(pf, 6, str(lnk), 1); hr != 0 { // Save
		return fmt.Errorf("saving the shortcut: 0x%X", hr)
	}
	return nil
}

// centreWindow puts the window in the middle of the screen's work area (after its size changed).
func centreWindow(hwnd uintptr) {
	user32 := windows.NewLazySystemDLL("user32.dll")
	var r [4]int32
	if ok, _, _ := user32.NewProc("GetWindowRect").Call(hwnd, uintptr(unsafe.Pointer(&r))); ok == 0 {
		return
	}
	var wa [4]int32
	if ok, _, _ := user32.NewProc("SystemParametersInfoW").Call(0x0030, 0, uintptr(unsafe.Pointer(&wa)), 0); ok == 0 { // SPI_GETWORKAREA
		return
	}
	w, h := r[2]-r[0], r[3]-r[1]
	x, y := wa[0]+(wa[2]-wa[0]-w)/2, wa[1]+(wa[3]-wa[1]-h)/2
	user32.NewProc("SetWindowPos").Call(hwnd, 0, uintptr(x), uintptr(y), 0, 0, 0x0001|0x0004|0x0010) // NOSIZE|NOZORDER|NOACTIVATE
}

func hideWindow(hwnd uintptr) {
	windows.NewLazySystemDLL("user32.dll").NewProc("ShowWindow").Call(hwnd, 0) // SW_HIDE
}

// launcherUnavailable: the launcher's window couldn't be made, almost always because the PC has no
// Microsoft Edge WebView2 Runtime (Windows 11 has it; some Windows 10 PCs don't): say so and offer
// Microsoft's download page.
func launcherUnavailable() {
	if askYesNo("VSRG Hub", "VSRG Hub's window needs the Microsoft Edge WebView2 Runtime, which isn't on this PC.\n\nIt's free, from Microsoft (Windows 11 already has it). Open the download page now?\n\nInstall \"Evergreen Bootstrapper\", then start VSRG Hub again.") {
		openURL("https://developer.microsoft.com/microsoft-edge/webview2/")
	}
}

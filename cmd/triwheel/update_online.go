package main

// Updates from the internet, for the launcher: a small JSON file (the "update feed", release/ in the
// public GitHub repository Naidez7/vsrghub, with the version zips beside it) says which version is the newest, where its zip is, and what each version brought.
// update-url.txt (next to vsrghub.exe, in Etterna's Save/VSRGHub folder or the launcher's own
// folder) can name another address.
//
//	{"latest": {"version": "1.8.0-beta.34", "url": "https://.../VSRGHub-1.8.0-beta.34.zip",
//	  "sha256": "<hex of the zip>", "notes": "what's new"},
//	 "changelog": [{"version": "1.8.0-beta.34", "date": "2026-10-15", "notes": "..."}, ...]}
//
// (The first launchers read "version", "url", "sha256" and "notes" at the top: the feed has those too.)
//
// The zip is only installed when its SHA-256 matches, so a broken or swapped download never is.

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type onlineUpdate struct {
	Version string `json:"version"`
	URL     string `json:"url"`
	SHA256  string `json:"sha256"`
	Notes   string `json:"notes"`
}

// updateManifestURL is where the update feed is: update-url.txt when there is one, else the built-in
// address ("" when there is neither).
func updateManifestURL(home, data string) string {
	var paths []string
	if exe, err := os.Executable(); err == nil {
		paths = append(paths, filepath.Join(filepath.Dir(exe), "update-url.txt"))
	}
	if home != "" {
		paths = append(paths, filepath.Join(home, "update-url.txt"))
	}
	if data != "" {
		paths = append(paths, filepath.Join(data, "update-url.txt"))
	}
	paths = append(paths, filepath.Join(launcherDir(), "update-url.txt"))
	for _, p := range paths {
		for _, l := range readLines(p) {
			if strings.HasPrefix(l, "https://") {
				return l
			}
		}
	}
	return defaultFeedURL
}

var updateClient = &http.Client{Timeout: 15 * time.Second}

// readFeed reads the update feed: the newest version (in "latest", or at the top as the first
// launchers read it) and the notes of every version.
func readFeed(feedURL string) (updateFeed, error) {
	var f updateFeed
	// (GitHub's raw files are cached for a few minutes: a query of its own each time gets the newest)
	if strings.Contains(feedURL, "raw.githubusercontent.com") && !strings.Contains(feedURL, "?") {
		feedURL += fmt.Sprintf("?t=%d", time.Now().Unix())
	}
	req, err := http.NewRequest("GET", feedURL, nil)
	if err != nil {
		return f, err
	}
	req.Header.Set("User-Agent", "VSRG-Hub/"+version)
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := updateClient.Do(req)
	if err != nil {
		return f, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return f, fmt.Errorf("the update server answered %s", resp.Status)
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 4<<20)).Decode(&f); err != nil {
		return f, fmt.Errorf("the update file couldn't be read: %v", err)
	}
	if f.Latest == nil && f.Version != "" {
		u := f.onlineUpdate
		f.Latest = &u
	}
	if f.Latest != nil {
		f.Latest.SHA256 = strings.ToLower(strings.TrimSpace(f.Latest.SHA256))
	}
	return f, nil
}

// checkOnlineUpdate reads the feed. ok is true when it names a version newer than this one.
func checkOnlineUpdate(feedURL string) (u onlineUpdate, ok bool, err error) {
	f, err := readFeed(feedURL)
	if err != nil {
		return u, false, err
	}
	if f.Latest == nil {
		return u, false, fmt.Errorf("the update file names no version")
	}
	u = *f.Latest
	if u.Version == "" || !strings.HasPrefix(u.URL, "https://") || len(u.SHA256) != 64 {
		return u, false, fmt.Errorf("the update file is incomplete")
	}
	return u, newerVersion(u.Version, version), nil
}

// downloadUpdate fetches the zip into dir, checks it and returns its path. progress gets the
// bytes so far and the total (0 when the server doesn't say).
func downloadUpdate(u onlineUpdate, dir string, progress func(done, total int64)) (string, error) {
	os.MkdirAll(dir, 0o755)
	dst := filepath.Join(dir, "VSRGHub-"+safeFileName(u.Version)+".zip")
	tmp := dst + ".part"
	req, err := http.NewRequest("GET", u.URL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "VSRG-Hub/"+version)
	client := &http.Client{Timeout: 15 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("the download answered %s", resp.Status)
	}
	f, err := os.Create(tmp)
	if err != nil {
		return "", err
	}
	h := sha256.New()
	total := resp.ContentLength
	var done int64
	buf := make([]byte, 256<<10)
	last := time.Time{}
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := f.Write(buf[:n]); werr != nil {
				f.Close()
				os.Remove(tmp)
				return "", werr
			}
			h.Write(buf[:n])
			done += int64(n)
			if time.Since(last) > 100*time.Millisecond {
				last = time.Now()
				progress(done, total)
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			f.Close()
			os.Remove(tmp)
			return "", rerr
		}
	}
	f.Close()
	progress(done, total)
	if got := hex.EncodeToString(h.Sum(nil)); got != u.SHA256 {
		os.Remove(tmp)
		return "", fmt.Errorf("the download is damaged (its checksum doesn't match); try again")
	}
	os.Remove(dst)
	if err := os.Rename(tmp, dst); err != nil {
		return "", err
	}
	return dst, nil
}

func safeFileName(s string) string {
	return strings.Map(func(r rune) rune {
		if r == '.' || r == '-' || r == '_' || (r >= '0' && r <= '9') || (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
			return r
		}
		return '_'
	}, s)
}

// setPickedTheme writes the look the game starts in (theme= in VSRG Hub's settings.ini, which the
// looks' own theme picker writes too), keeping the other settings.
func setPickedTheme(data, theme string) error {
	p := filepath.Join(data, "settings.ini")
	b, _ := os.ReadFile(p)
	var out []string
	found := false
	for _, l := range strings.Split(strings.ReplaceAll(string(b), "\r", ""), "\n") {
		if l == "" {
			continue
		}
		if strings.HasPrefix(l, "theme=") {
			l, found = "theme="+theme, true
		}
		out = append(out, l)
	}
	if !found {
		out = append(out, "theme="+theme)
	}
	return os.WriteFile(p, []byte(strings.Join(out, "\n")+"\n"), 0o644)
}

// availableThemes lists the looks that can be picked here.
func availableThemes(etterna, home string) []string {
	root := filepath.Join(home, "Root")
	var out []string
	for _, t := range []string{themeName, lazerThemeName, quaverThemeName} {
		if dirExists(filepath.Join(root, "Themes", t)) {
			out = append(out, t)
		}
	}
	for _, t := range etternaThemes {
		if dirExists(filepath.Join(etterna, "Themes", t)) {
			out = append(out, t)
		}
	}
	return out
}

// writeUpdateNotice tells the game when a newer VSRG Hub is out (its main menu shows it):
// Save/VSRGHub/update.txt holds the newest version, and is removed when the game is up to date.
func writeUpdateNotice(home, data string) {
	p := filepath.Join(data, "update.txt")
	u, _, err := checkOnlineUpdate(updateManifestURL(home, data))
	if err != nil {
		return // (offline: the last word stays)
	}
	cur := installedVersion(home)
	if cur == "" || cur == "?" {
		cur = version
	}
	if newerVersion(u.Version, cur) {
		os.WriteFile(p, []byte(u.Version+"\n"), 0o644)
		logf("update: VSRG Hub %s is out (this is %s)", u.Version, cur)
	} else {
		os.Remove(p)
	}
}

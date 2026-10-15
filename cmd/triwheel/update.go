package main

// Installing a new version from its zip: drop the zip on vsrghub.exe, or just leave it in Downloads
// (or the Etterna folder) and start VSRG Hub; it asks, puts the new files over the old ones and
// starts the new version. The songs, scores and settings stay (they live in Etterna's Save folder).

import (
	"archive/zip"
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// parseVersion reads "1.8.0-beta.20" into numbers and a pre-release part.
func parseVersion(v string) (nums []int, pre string, ok bool) {
	v = strings.TrimPrefix(strings.TrimSpace(v), "v")
	main, pre, _ := strings.Cut(v, "-")
	for _, p := range strings.Split(main, ".") {
		n, err := strconv.Atoi(p)
		if err != nil {
			return nil, "", false
		}
		nums = append(nums, n)
	}
	return nums, pre, len(nums) > 0
}

// newerVersion reports whether a is newer than b (1.9.0 > 1.9.0-beta.3 > 1.9.0-beta.2 > 1.8.0).
func newerVersion(a, b string) bool {
	an, ap, ok1 := parseVersion(a)
	bn, bp, ok2 := parseVersion(b)
	if !ok1 || !ok2 {
		return false
	}
	for i := 0; i < len(an) || i < len(bn); i++ {
		x, y := 0, 0
		if i < len(an) {
			x = an[i]
		}
		if i < len(bn) {
			y = bn[i]
		}
		if x != y {
			return x > y
		}
	}
	if ap == bp {
		return false
	}
	if ap == "" || bp == "" {
		return ap == "" // a release beats its pre-releases
	}
	// beta.20 > beta.3: compare dot parts, numbers as numbers
	as, bs := strings.Split(ap, "."), strings.Split(bp, ".")
	for i := 0; i < len(as) && i < len(bs); i++ {
		if as[i] == bs[i] {
			continue
		}
		x, e1 := strconv.Atoi(as[i])
		y, e2 := strconv.Atoi(bs[i])
		if e1 == nil && e2 == nil {
			return x > y
		}
		return as[i] > bs[i]
	}
	return len(as) > len(bs)
}

type updateZip struct {
	path, version, prefix string
}

var zipNameVersion = regexp.MustCompile(`(?i)vsrghub[-_ ]?v?([0-9]+(?:\.[0-9]+)*(?:-[a-z]+(?:\.[0-9]+)?)?)`)

// readUpdateZip checks that a zip holds VSRG Hub and finds its version.
func readUpdateZip(path string) (updateZip, bool) {
	z, err := zip.OpenReader(path)
	if err != nil {
		return updateZip{}, false
	}
	defer z.Close()
	u := updateZip{path: path, prefix: "-"}
	for _, f := range z.File {
		name := strings.ReplaceAll(f.Name, `\`, "/")
		if strings.EqualFold(filepath.Base(name), "vsrghub.exe") {
			u.prefix = strings.TrimSuffix(name, filepath.Base(name))
		}
	}
	if u.prefix == "-" {
		return updateZip{}, false
	}
	for _, f := range z.File {
		if strings.EqualFold(strings.ReplaceAll(f.Name, `\`, "/"), u.prefix+"version.txt") {
			if r, err := f.Open(); err == nil {
				b, _ := io.ReadAll(io.LimitReader(r, 100))
				r.Close()
				u.version = strings.TrimSpace(string(b))
			}
		}
	}
	if u.version == "" {
		if m := zipNameVersion.FindStringSubmatch(filepath.Base(path)); m != nil {
			u.version = m[1]
		}
	}
	return u, u.version != ""
}

// findUpdateZip looks for the newest VSRG Hub zip newer than this one where people usually leave it.
func findUpdateZip(etterna, home string) (updateZip, bool) {
	var dirs []string
	dirs = append(dirs, etterna, home)
	if h := os.Getenv("USERPROFILE"); h != "" {
		dirs = append(dirs, filepath.Join(h, "Downloads"), filepath.Join(h, "Desktop"))
	}
	best := updateZip{}
	for _, d := range dirs {
		entries, err := os.ReadDir(d)
		if err != nil {
			continue
		}
		for _, e := range entries {
			n := strings.ToLower(e.Name())
			if e.IsDir() || !strings.HasSuffix(n, ".zip") || !strings.HasPrefix(n, "vsrghub") {
				continue
			}
			if u, ok := readUpdateZip(filepath.Join(d, e.Name())); ok && newerVersion(u.version, version) {
				if best.version == "" || newerVersion(u.version, best.version) {
					best = u
				}
			}
		}
	}
	return best, best.version != ""
}

func readLines(p string) []string {
	f, err := os.Open(p)
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if l := strings.TrimSpace(sc.Text()); l != "" {
			out = append(out, l)
		}
	}
	return out
}

// installZip puts the zip's files over the VSRGHub folder. The running vsrghub.exe is renamed out of
// the way first (Windows lets a running program be renamed, not replaced).
func installZip(u updateZip, home, data string) error {
	z, err := zip.OpenReader(u.path)
	if err != nil {
		return err
	}
	defer z.Close()
	exe := filepath.Join(home, "vsrghub.exe")
	old := exe + ".old"
	clearOldSelves(exe)
	if err := os.Rename(exe, old); err != nil && !os.IsNotExist(err) {
		// (the last ".old" still held: a fresh name)
		old = fmt.Sprintf("%s.old%d", exe, time.Now().Unix()%100000)
		if err := os.Rename(exe, old); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("moving the running vsrghub.exe aside: %w", err)
		}
	}
	restore := func() { os.Remove(exe); os.Rename(old, exe) }
	// the files the installed version shipped (its files.txt), to clear out the ones the new one dropped
	listPath := filepath.Join(data, "installed-files.txt")
	before := readLines(filepath.Join(home, "files.txt"))
	if len(before) == 0 {
		before = readLines(listPath)
	}
	var files []string
	homeAbs, _ := filepath.Abs(home)
	for _, f := range z.File {
		name := strings.ReplaceAll(f.Name, `\`, "/")
		if !strings.HasPrefix(name, u.prefix) || strings.HasSuffix(name, "/") {
			continue
		}
		rel := strings.TrimPrefix(name, u.prefix)
		dst := filepath.Join(home, filepath.FromSlash(rel))
		if abs, _ := filepath.Abs(dst); !strings.HasPrefix(abs, homeAbs+string(filepath.Separator)) {
			continue // (nothing outside the VSRGHub folder)
		}
		os.MkdirAll(filepath.Dir(dst), 0o755)
		r, err := f.Open()
		if err != nil {
			restore()
			return err
		}
		w, err := os.Create(dst)
		if err != nil {
			r.Close()
			if rel == "vsrghub.exe" {
				restore()
				return err
			}
			logf("update: %s: %v", rel, err)
			continue
		}
		_, err = io.Copy(w, r)
		r.Close()
		w.Close()
		if err != nil {
			if rel == "vsrghub.exe" {
				restore()
			}
			return err
		}
		files = append(files, filepath.ToSlash(rel))
	}
	if _, err := os.Stat(exe); err != nil {
		restore()
		return fmt.Errorf("the zip has no vsrghub.exe")
	}
	// files the old version shipped that the new one doesn't (a theme script renamed or removed)
	now := map[string]bool{}
	for _, f := range files {
		now[strings.ToLower(f)] = true
	}
	for _, f := range before {
		if !now[strings.ToLower(f)] && f != "vsrghub.exe" && !strings.HasPrefix(strings.ToLower(f), "library/") {
			os.Remove(filepath.Join(home, filepath.FromSlash(f)))
		}
	}
	sort.Strings(files)
	os.WriteFile(listPath, []byte(strings.Join(files, "\n")+"\n"), 0o644)
	return nil
}

// updateFromZip installs a newer version when one is dropped on vsrghub.exe or found in Downloads,
// and starts it. It returns true when the new version was started (this one then just ends).
func updateFromZip(etterna, home, data string, zipArgs []string) bool {
	os.Remove(filepath.Join(home, "vsrghub.exe.old")) // (left by the last update)
	var u updateZip
	var found bool
	explicit := false
	for _, z := range zipArgs {
		if uu, ok := readUpdateZip(z); ok {
			u, found, explicit = uu, true, true
		} else {
			logf("update: %s isn't a VSRG Hub zip", z)
		}
	}
	if !found {
		u, found = findUpdateZip(etterna, home)
	}
	if !found {
		return false
	}
	declined := filepath.Join(data, "update-declined.txt")
	key := u.path + "|" + u.version
	if !explicit {
		for _, l := range readLines(declined) {
			if l == key {
				return false
			}
		}
	}
	what := "Install it now?"
	if explicit && !newerVersion(u.version, version) {
		what = "It is not newer than this one (" + version + "). Install it anyway?"
	}
	msg := fmt.Sprintf("VSRG Hub %s found:\n%s\n\nThis is VSRG Hub %s. %s\n\nYour songs, scores and settings stay as they are.", u.version, u.path, version, what)
	if !askYesNo("VSRG Hub update", msg) {
		if !explicit {
			f, _ := os.OpenFile(declined, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
			if f != nil {
				fmt.Fprintln(f, key)
				f.Close()
			}
		}
		logf("update: %s not installed (declined)", u.version)
		return false
	}
	if err := installZip(u, home, data); err != nil {
		logf("update: installing %s failed: %v", u.version, err)
		showMessage("VSRG Hub update", "The update could not be installed:\n"+err.Error()+"\n\nVSRG Hub "+version+" starts as before.")
		return false
	}
	logf("update: installed %s from %s; starting it", u.version, u.path)
	var args []string
	for _, a := range os.Args[1:] {
		if !strings.EqualFold(filepath.Ext(a), ".zip") {
			args = append(args, a)
		}
	}
	cmd := exec.Command(filepath.Join(home, "vsrghub.exe"), args...)
	cmd.Dir = home
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Start(); err != nil {
		logf("update: starting the new version: %v", err)
		return false
	}
	return true
}

//go:build windows

package main

// Where Windows says the games are: osu!'s link handler and Steam's own path in the registry.

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/sys/windows/registry"
)

func regString(root registry.Key, path, name string) string {
	k, err := registry.OpenKey(root, path, registry.QUERY_VALUE|registry.WOW64_64KEY)
	if err != nil {
		k, err = registry.OpenKey(root, path, registry.QUERY_VALUE)
		if err != nil {
			return ""
		}
	}
	defer k.Close()
	v, _, err := k.GetStringValue(name)
	if err != nil {
		return ""
	}
	return v
}

var exeInCommand = regexp.MustCompile(`(?i)"?([a-z]:\\[^"]*?\.exe)"?`)

// osu!'s installer registers "osu://" links and .osz files with the osu!.exe it installed, wherever
// that is (any drive, any folder).
func registryOsuDirs() []string {
	var out []string
	for _, p := range []struct {
		root registry.Key
		path string
	}{
		{registry.CLASSES_ROOT, `osu\shell\open\command`},
		{registry.CURRENT_USER, `Software\Classes\osu\shell\open\command`},
		{registry.CLASSES_ROOT, `osustable.File.osz\shell\open\command`},
		{registry.CURRENT_USER, `Software\Classes\osustable.File.osz\shell\open\command`},
		{registry.CLASSES_ROOT, `osu\DefaultIcon`},
	} {
		if m := exeInCommand.FindStringSubmatch(regString(p.root, p.path, "")); m != nil {
			if strings.EqualFold(filepath.Base(m[1]), "osu!.exe") {
				out = append(out, filepath.Dir(m[1]))
			}
		}
	}
	return out
}

// Steam's own folder, wherever it was installed.
func registrySteamDirs() []string {
	var out []string
	if v := regString(registry.CURRENT_USER, `Software\Valve\Steam`, "SteamPath"); v != "" {
		out = append(out, filepath.Clean(strings.ReplaceAll(v, "/", `\`)))
	}
	for _, p := range []string{`SOFTWARE\WOW6432Node\Valve\Steam`, `SOFTWARE\Valve\Steam`} {
		if v := regString(registry.LOCAL_MACHINE, p, "InstallPath"); v != "" {
			out = append(out, filepath.Clean(v))
		}
	}
	return out
}

// The drives in use (C:\, D:\, ...).
func driveRoots() []string {
	var out []string
	for c := 'C'; c <= 'Z'; c++ {
		r := string(c) + `:\`
		if _, err := os.Stat(r); err == nil {
			out = append(out, r)
		}
	}
	return out
}

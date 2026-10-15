//go:build windows

package main

// Windows bits the launcher needs: the folder and file pickers, the screen's display modes,
// opening a web page, the Start menu, reading a shortcut, and where Etterna's installer put it.

import (
	_ "embed"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

var (
	clsidFileOpenDialog = windows.GUID{Data1: 0xDC1C5A9C, Data2: 0xE88A, Data3: 0x4DDE, Data4: [8]byte{0xA5, 0xA1, 0x60, 0xF8, 0x2A, 0x20, 0xAE, 0xF7}}
	iidIFileOpenDialog  = windows.GUID{Data1: 0xD57C7288, Data2: 0xD4AD, Data3: 0x4768, Data4: [8]byte{0xBE, 0x02, 0x9D, 0x96, 0x95, 0x32, 0xD9, 0x60}}
	iidIShellItem       = windows.GUID{Data1: 0x43826D1E, Data2: 0xE718, Data3: 0x42EE, Data4: [8]byte{0xBC, 0x55, 0xA1, 0xE2, 0x61, 0xC3, 0x7B, 0xFE}}
)

type comdlgFilter struct{ name, spec *uint16 }

// pickPath shows Windows' own Open dialog over owner: a folder (folder true) or a file of the
// given pattern ("*.zip"). start is where it opens. "" when nothing was picked.
func pickPath(owner uintptr, title, start string, folder bool, filterName, pattern string) string {
	ole := windows.NewLazySystemDLL("ole32.dll")
	ole.NewProc("CoInitializeEx").Call(0, 2)
	var dlg uintptr
	if hr, _, _ := ole.NewProc("CoCreateInstance").Call(uintptr(unsafe.Pointer(&clsidFileOpenDialog)), 0, 1,
		uintptr(unsafe.Pointer(&iidIFileOpenDialog)), uintptr(unsafe.Pointer(&dlg))); hr != 0 || dlg == 0 {
		logf("launcher: the Open dialog: 0x%X", hr)
		return ""
	}
	defer comCall(dlg, 2)
	var keep []*uint16
	str := func(s string) *uint16 {
		p, _ := windows.UTF16PtrFromString(s)
		keep = append(keep, p)
		return p
	}
	defer runtime.KeepAlive(&keep)
	var opts uint32
	comCall(dlg, 10, uintptr(unsafe.Pointer(&opts))) // GetOptions
	opts |= 0x40 | 0x800 | 0x1000                    // FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST | FOS_FILEMUSTEXIST
	if folder {
		opts |= 0x20 // FOS_PICKFOLDERS
	}
	comCall(dlg, 9, uintptr(opts)) // SetOptions
	comCall(dlg, 17, uintptr(unsafe.Pointer(str(title))))
	if !folder && pattern != "" {
		f := []comdlgFilter{{str(filterName), str(pattern)}}
		comCall(dlg, 4, 1, uintptr(unsafe.Pointer(&f[0]))) // SetFileTypes
		runtime.KeepAlive(f)
	}
	if start != "" && dirExists(start) {
		shell := windows.NewLazySystemDLL("shell32.dll")
		var item uintptr
		if hr, _, _ := shell.NewProc("SHCreateItemFromParsingName").Call(uintptr(unsafe.Pointer(str(start))), 0,
			uintptr(unsafe.Pointer(&iidIShellItem)), uintptr(unsafe.Pointer(&item))); hr == 0 && item != 0 {
			comCall(dlg, 12, item) // SetFolder
			comCall(item, 2)
		}
	}
	if hr := comCall(dlg, 3, owner); hr != 0 { // Show (cancelled: ERROR_CANCELLED)
		return ""
	}
	var res uintptr
	if hr := comCall(dlg, 20, uintptr(unsafe.Pointer(&res))); hr != 0 || res == 0 { // GetResult
		return ""
	}
	defer comCall(res, 2)
	var name *uint16
	if hr := comCall(res, 5, 0x80058000, uintptr(unsafe.Pointer(&name))); hr != 0 || name == nil { // GetDisplayName(SIGDN_FILESYSPATH)
		return ""
	}
	defer windows.CoTaskMemFree(unsafe.Pointer(name))
	return windows.UTF16PtrToString(name)
}

// the screen's display modes: "1920x1080" sizes, biggest first, and the refresh rates
type devmode struct {
	DeviceName       [32]uint16
	SpecVersion      uint16
	DriverVersion    uint16
	Size             uint16
	DriverExtra      uint16
	Fields           uint32
	Position         [2]int32
	DisplayOrient    uint32
	DisplayFixed     uint32
	Color            int16
	Duplex           int16
	YResolution      int16
	TTOption         int16
	Collate          int16
	FormName         [32]uint16
	LogPixels        uint16
	BitsPerPel       uint32
	PelsWidth        uint32
	PelsHeight       uint32
	DisplayFlags     uint32
	DisplayFrequency uint32
	ICMMethod        uint32
	ICMIntent        uint32
	MediaType        uint32
	DitherType       uint32
	Reserved1        uint32
	Reserved2        uint32
	PanningWidth     uint32
	PanningHeight    uint32
}

func displayModes() (sizes []string, rates []int, current string, currentRate int) {
	p := windows.NewLazySystemDLL("user32.dll").NewProc("EnumDisplaySettingsW")
	seen := map[string]bool{}
	seenRate := map[int]bool{}
	type wh struct{ w, h int }
	var list []wh
	for i := 0; ; i++ {
		var dm devmode
		dm.Size = uint16(unsafe.Sizeof(dm))
		if r, _, _ := p.Call(0, uintptr(i), uintptr(unsafe.Pointer(&dm))); r == 0 {
			break
		}
		if dm.BitsPerPel < 24 || dm.PelsWidth < 800 {
			continue
		}
		k := strings.Join([]string{itoa(int(dm.PelsWidth)), itoa(int(dm.PelsHeight))}, "x")
		if !seen[k] {
			seen[k] = true
			list = append(list, wh{int(dm.PelsWidth), int(dm.PelsHeight)})
		}
		if f := int(dm.DisplayFrequency); f > 1 && !seenRate[f] {
			seenRate[f] = true
			rates = append(rates, f)
		}
	}
	var dm devmode
	dm.Size = uint16(unsafe.Sizeof(dm))
	if r, _, _ := p.Call(0, 0xFFFFFFFF, uintptr(unsafe.Pointer(&dm))); r != 0 { // ENUM_CURRENT_SETTINGS
		current = itoa(int(dm.PelsWidth)) + "x" + itoa(int(dm.PelsHeight))
		currentRate = int(dm.DisplayFrequency)
	}
	sort.Slice(list, func(i, j int) bool {
		if list[i].w != list[j].w {
			return list[i].w > list[j].w
		}
		return list[i].h > list[j].h
	})
	for _, s := range list {
		sizes = append(sizes, itoa(s.w)+"x"+itoa(s.h))
	}
	sort.Sort(sort.Reverse(sort.IntSlice(rates)))
	return
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	if neg {
		b = append([]byte{'-'}, b...)
	}
	return string(b)
}

// openURL opens a web page in the default browser (https only).
func openURL(u string) {
	if !strings.HasPrefix(u, "https://") {
		return
	}
	p, _ := windows.UTF16PtrFromString(u)
	verb, _ := windows.UTF16PtrFromString("open")
	windows.ShellExecute(0, verb, p, nil, nil, 1)
}

func openFolder(d string) { exec.Command("explorer.exe", d).Start() }

// the Start menu's Programs folder of this user
func startMenuDir() string {
	if d, err := windows.KnownFolderPath(windows.FOLDERID_Programs, 0); err == nil && d != "" {
		return d
	}
	return filepath.Join(os.Getenv("APPDATA"), `Microsoft\Windows\Start Menu\Programs`)
}

// makeShortcut saves a shortcut (.lnk) to target.
func makeShortcut(lnk, target, workDir string) error {
	errc := make(chan error, 1)
	go func() {
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		errc <- shellLink(lnk, target, workDir)
	}()
	return <-errc
}

// shortcutTarget reads where a shortcut points ("" when it can't be read).
func shortcutTarget(lnk string) string {
	out := make(chan string, 1)
	go func() {
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		ole := windows.NewLazySystemDLL("ole32.dll")
		ole.NewProc("CoInitializeEx").Call(0, 2)
		defer ole.NewProc("CoUninitialize").Call()
		var link uintptr
		if hr, _, _ := ole.NewProc("CoCreateInstance").Call(uintptr(unsafe.Pointer(&clsidShellLink)), 0, 1,
			uintptr(unsafe.Pointer(&iidIShellLinkW)), uintptr(unsafe.Pointer(&link))); hr != 0 || link == 0 {
			out <- ""
			return
		}
		defer comCall(link, 2)
		var pf uintptr
		if hr := comCall(link, 0, uintptr(unsafe.Pointer(&iidIPersistFile)), uintptr(unsafe.Pointer(&pf))); hr != 0 || pf == 0 {
			out <- ""
			return
		}
		defer comCall(pf, 2)
		p, _ := windows.UTF16PtrFromString(lnk)
		if hr := comCall(pf, 5, uintptr(unsafe.Pointer(p)), 0); hr != 0 { // Load
			out <- ""
			return
		}
		buf := make([]uint16, 1024)
		if hr := comCall(link, 3, uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)), 0, 0); hr != 0 { // GetPath
			out <- ""
			return
		}
		out <- windows.UTF16ToString(buf)
	}()
	return <-out
}

// where Etterna's installer says it put Etterna (the Uninstall entries in the registry)
func registryEtternaDirs() []string {
	var out []string
	for _, root := range []registry.Key{registry.LOCAL_MACHINE, registry.CURRENT_USER} {
		for _, base := range []string{`SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`, `SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`} {
			k, err := registry.OpenKey(root, base, registry.ENUMERATE_SUB_KEYS|registry.QUERY_VALUE)
			if err != nil {
				continue
			}
			names, _ := k.ReadSubKeyNames(-1)
			k.Close()
			for _, n := range names {
				sk, err := registry.OpenKey(root, base+`\`+n, registry.QUERY_VALUE)
				if err != nil {
					continue
				}
				dn, _, _ := sk.GetStringValue("DisplayName")
				if strings.Contains(strings.ToLower(dn), "etterna") {
					if loc, _, err := sk.GetStringValue("InstallLocation"); err == nil && loc != "" {
						out = append(out, strings.Trim(loc, `"`))
					}
					if un, _, err := sk.GetStringValue("UninstallString"); err == nil && un != "" {
						out = append(out, filepath.Dir(strings.Trim(strings.Fields(un + " ")[0], `"`)))
						if m := exeInCommand.FindStringSubmatch(un); m != nil {
							out = append(out, filepath.Dir(m[1]))
						}
					}
					if ic, _, err := sk.GetStringValue("DisplayIcon"); err == nil && ic != "" {
						if m := exeInCommand.FindStringSubmatch(ic); m != nil {
							d := filepath.Dir(m[1])
							out = append(out, d, filepath.Dir(d))
						}
					}
				}
				sk.Close()
			}
		}
	}
	return out
}

//go:embed webview2loader.dll
var webview2Loader []byte

// prepareWebView2 makes sure WebView2Loader.dll can be found: next to the program (the VSRGHub
// folder has it), else a copy in the launcher's own folder is loaded first, so the program can sit
// on its own (on the desktop, say) without the DLL beside it.
func prepareWebView2() {
	if exe, err := os.Executable(); err == nil && fileExists(filepath.Join(filepath.Dir(exe), "WebView2Loader.dll")) {
		return
	}
	dst := filepath.Join(launcherDir(), "WebView2Loader.dll")
	if st, err := os.Stat(dst); err != nil || st.Size() != int64(len(webview2Loader)) {
		os.WriteFile(dst, webview2Loader, 0o644)
	}
	if _, err := windows.LoadLibrary(dst); err != nil {
		logf("launcher: WebView2Loader.dll: %v", err)
	}
}

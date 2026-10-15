package main

// A small icon in Windows' notification area while the game runs: its tooltip says how many plays
// wait to be sent to VSRG Hub's ranking. (A window of its own, hidden, receives the shell's
// messages; the icon goes when the game ends.)

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

type notifyIconData struct {
	Size            uint32
	Wnd             windows.Handle
	ID              uint32
	Flags           uint32
	CallbackMessage uint32
	Icon            windows.Handle
	Tip             [128]uint16
	State           uint32
	StateMask       uint32
	Info            [256]uint16
	Version         uint32
	InfoTitle       [64]uint16
	InfoFlags       uint32
	GuidItem        windows.GUID
	BalloonIcon     windows.Handle
}

type wndClassEx struct {
	Size       uint32
	Style      uint32
	WndProc    uintptr
	ClsExtra   int32
	WndExtra   int32
	Instance   windows.Handle
	Icon       windows.Handle
	Cursor     windows.Handle
	Background windows.Handle
	MenuName   *uint16
	ClassName  *uint16
	IconSm     windows.Handle
}

type msg struct {
	Wnd     windows.Handle
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      struct{ X, Y int32 }
}

// startTray shows the icon; the returned function takes it away. tip() gives the words to show.
func startTray(tip func() string) func() {
	user32 := windows.NewLazySystemDLL("user32.dll")
	shell32 := windows.NewLazySystemDLL("shell32.dll")
	kernel32 := windows.NewLazySystemDLL("kernel32.dll")
	done := make(chan struct{})
	var hwnd windows.Handle
	ready := make(chan bool, 1)
	go func() {
		// (the window and its messages stay on one thread)
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		inst, _, _ := kernel32.NewProc("GetModuleHandleW").Call(0)
		className, _ := syscall.UTF16PtrFromString("VSRGHubTray")
		proc := syscall.NewCallback(func(h windows.Handle, m uint32, wp, lp uintptr) uintptr {
			r, _, _ := user32.NewProc("DefWindowProcW").Call(uintptr(h), uintptr(m), wp, lp)
			return r
		})
		wc := wndClassEx{Size: uint32(unsafe.Sizeof(wndClassEx{})), WndProc: proc, Instance: windows.Handle(inst), ClassName: className}
		user32.NewProc("RegisterClassExW").Call(uintptr(unsafe.Pointer(&wc)))
		title, _ := syscall.UTF16PtrFromString("VSRG Hub")
		h, _, _ := user32.NewProc("CreateWindowExW").Call(0, uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(title)), 0, 0, 0, 0, 0, 0, 0, inst, 0)
		if h == 0 {
			ready <- false
			return
		}
		hwnd = windows.Handle(h)
		// the program's own icon
		var icon windows.Handle
		if exe, err := os.Executable(); err == nil {
			p, _ := syscall.UTF16PtrFromString(filepath.Clean(exe))
			ic, _, _ := shell32.NewProc("ExtractIconW").Call(inst, uintptr(unsafe.Pointer(p)), 0)
			if ic > 1 {
				icon = windows.Handle(ic)
			}
		}
		if icon == 0 {
			ic, _, _ := user32.NewProc("LoadIconW").Call(0, 32512) // IDI_APPLICATION
			icon = windows.Handle(ic)
		}
		nid := notifyIconData{Size: uint32(unsafe.Sizeof(notifyIconData{})), Wnd: hwnd, ID: 1, Flags: 1 | 2 | 4, CallbackMessage: 0x0400 + 1, Icon: icon}
		setTip := func(s string) {
			u, _ := syscall.UTF16FromString(s)
			for i := range nid.Tip {
				nid.Tip[i] = 0
			}
			copy(nid.Tip[:127], u)
		}
		setTip(tip())
		shell32.NewProc("Shell_NotifyIconW").Call(0, uintptr(unsafe.Pointer(&nid))) // NIM_ADD
		ready <- true
		// the tooltip kept fresh, the window's messages seen to, until the game ends
		tick := time.NewTicker(3 * time.Second)
		defer tick.Stop()
		var m msg
		for {
			select {
			case <-done:
				shell32.NewProc("Shell_NotifyIconW").Call(2, uintptr(unsafe.Pointer(&nid))) // NIM_DELETE
				user32.NewProc("DestroyWindow").Call(uintptr(hwnd))
				return
			case <-tick.C:
				setTip(tip())
				shell32.NewProc("Shell_NotifyIconW").Call(1, uintptr(unsafe.Pointer(&nid))) // NIM_MODIFY
			default:
			}
			for {
				r, _, _ := user32.NewProc("PeekMessageW").Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0, 1)
				if r == 0 {
					break
				}
				user32.NewProc("TranslateMessage").Call(uintptr(unsafe.Pointer(&m)))
				user32.NewProc("DispatchMessageW").Call(uintptr(unsafe.Pointer(&m)))
			}
			time.Sleep(100 * time.Millisecond)
		}
	}()
	if !<-ready {
		return func() {}
	}
	return func() { close(done) }
}

// trayTip: what the icon's tooltip says
func trayTip(data string) string {
	if n := outboxCount(data); n > 0 {
		return fmt.Sprintf("VSRG Hub: %d play%s waiting to be sent", n, map[bool]string{true: "", false: "s"}[n == 1])
	}
	return "VSRG Hub: the game is running; plays are sent as you go"
}

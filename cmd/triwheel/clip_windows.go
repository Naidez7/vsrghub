//go:build windows

package main

import (
	"runtime"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	user32           = windows.NewLazySystemDLL("user32.dll")
	kernel32         = windows.NewLazySystemDLL("kernel32.dll")
	openClipboard    = user32.NewProc("OpenClipboard")
	closeClipboard   = user32.NewProc("CloseClipboard")
	getClipboardData = user32.NewProc("GetClipboardData")
	globalLock       = kernel32.NewProc("GlobalLock")
	globalUnlock     = kernel32.NewProc("GlobalUnlock")
)

const cfUnicodeText = 13

// clipboardText: the text on Windows' clipboard ("" when there is none)
func clipboardText() string {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	if r, _, _ := openClipboard.Call(0); r == 0 {
		return ""
	}
	defer closeClipboard.Call()
	h, _, _ := getClipboardData.Call(cfUnicodeText)
	if h == 0 {
		return ""
	}
	p, _, _ := globalLock.Call(h)
	if p == 0 {
		return ""
	}
	defer globalUnlock.Call(h)
	ptr := *(*unsafe.Pointer)(unsafe.Pointer(&p)) // (the locked memory, as a pointer)
	return windows.UTF16PtrToString((*uint16)(ptr))
}

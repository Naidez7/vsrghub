//go:build windows

package main

import "golang.org/x/sys/windows"

const (
	mbYesNo       = 0x4
	mbOK          = 0x0
	mbIconQuest   = 0x20
	mbIconInfo    = 0x40
	mbTopmost     = 0x40000
	mbSetForeGrnd = 0x10000
	idYes         = 6
)

func askYesNo(title, text string) bool {
	t, _ := windows.UTF16PtrFromString(text)
	c, _ := windows.UTF16PtrFromString(title)
	r, _ := windows.MessageBox(0, t, c, mbYesNo|mbIconQuest|mbTopmost|mbSetForeGrnd)
	return r == idYes
}

func showMessage(title, text string) {
	t, _ := windows.UTF16PtrFromString(text)
	c, _ := windows.UTF16PtrFromString(title)
	windows.MessageBox(0, t, c, mbOK|mbIconInfo|mbTopmost|mbSetForeGrnd)
}

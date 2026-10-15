package main

import (
	"fmt"
	"unsafe"

	"golang.org/x/sys/windows"
)

// The account's tokens are kept encrypted for this Windows user (DPAPI): another user of the PC, or
// the file copied to another PC, can't use them.
func protectData(b []byte) ([]byte, error) {
	in := windows.DataBlob{Size: uint32(len(b))}
	if len(b) > 0 {
		in.Data = &b[0]
	}
	var out windows.DataBlob
	if err := windows.CryptProtectData(&in, nil, nil, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &out); err != nil {
		return nil, err
	}
	defer windows.LocalFree(windows.Handle(unsafe.Pointer(out.Data)))
	return append([]byte(nil), unsafe.Slice(out.Data, out.Size)...), nil
}

func unprotectData(b []byte) ([]byte, error) {
	if len(b) == 0 {
		return nil, windows.ERROR_INVALID_DATA
	}
	in := windows.DataBlob{Size: uint32(len(b)), Data: &b[0]}
	var out windows.DataBlob
	if err := windows.CryptUnprotectData(&in, nil, nil, 0, nil, windows.CRYPTPROTECT_UI_FORBIDDEN, &out); err != nil {
		return nil, err
	}
	defer windows.LocalFree(windows.Handle(unsafe.Pointer(out.Data)))
	return append([]byte(nil), unsafe.Slice(out.Data, out.Size)...), nil
}

// windowsVersion: "10.0.22631" and the like (Windows 11 is 10.0 with a build of 22000 and up)
func windowsVersion() string {
	v := windows.RtlGetVersion()
	return fmt.Sprintf("%d.%d.%d", v.MajorVersion, v.MinorVersion, v.BuildNumber)
}

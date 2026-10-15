//go:build windows

package main

// Directory junctions (mount points): a folder that shows another folder's
// contents. They need no admin rights and nothing is copied.

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unicode/utf16"

	"golang.org/x/sys/windows"
)

const (
	fsctlSetReparsePoint = 0x000900A4
	fsctlGetReparsePoint = 0x000900A8
	ioReparseTagMountPt  = 0xA0000003
)

func isLink(p string) bool {
	ptr, err := windows.UTF16PtrFromString(p)
	if err != nil {
		return false
	}
	attrs, err := windows.GetFileAttributes(ptr)
	if err != nil {
		return false
	}
	return attrs&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0
}

// removeLink removes a junction itself; RemoveDirectory never touches the target.
func removeLink(p string) error {
	ptr, err := windows.UTF16PtrFromString(p)
	if err != nil {
		return err
	}
	return windows.RemoveDirectory(ptr)
}

func openReparse(p string, access uint32) (windows.Handle, error) {
	ptr, err := windows.UTF16PtrFromString(p)
	if err != nil {
		return 0, err
	}
	return windows.CreateFile(ptr, access, 0, nil, windows.OPEN_EXISTING,
		windows.FILE_FLAG_OPEN_REPARSE_POINT|windows.FILE_FLAG_BACKUP_SEMANTICS, 0)
}

func readJunction(p string) (string, error) {
	h, err := openReparse(p, windows.GENERIC_READ)
	if err != nil {
		return "", err
	}
	defer windows.CloseHandle(h)
	buf := make([]byte, 16*1024)
	var n uint32
	if err := windows.DeviceIoControl(h, fsctlGetReparsePoint, nil, 0, &buf[0], uint32(len(buf)), &n, nil); err != nil {
		return "", err
	}
	if binary.LittleEndian.Uint32(buf[0:]) != ioReparseTagMountPt {
		return "", fmt.Errorf("not a junction")
	}
	subOff := binary.LittleEndian.Uint16(buf[8:])
	subLen := binary.LittleEndian.Uint16(buf[10:])
	start := 16 + int(subOff)
	u := make([]uint16, subLen/2)
	for i := range u {
		u[i] = binary.LittleEndian.Uint16(buf[start+2*i:])
	}
	return strings.TrimPrefix(string(utf16.Decode(u)), `\??\`), nil
}

// ensureJunction makes link point at target, replacing an older junction we made.
func ensureJunction(link, target string) error {
	target, err := filepath.Abs(target)
	if err != nil {
		return err
	}
	if st, err := os.Stat(target); err != nil || !st.IsDir() {
		return fmt.Errorf("target %s is not a folder", target)
	}
	if isLink(link) {
		if cur, err := readJunction(link); err == nil && strings.EqualFold(filepath.Clean(cur), filepath.Clean(target)) {
			return nil
		}
		if err := removeLink(link); err != nil {
			return err
		}
	} else if _, err := os.Lstat(link); err == nil {
		return fmt.Errorf("%s exists and is not a junction; leaving it alone", link)
	}
	if err := os.MkdirAll(filepath.Dir(link), 0o755); err != nil {
		return err
	}
	if err := os.Mkdir(link, 0o755); err != nil {
		return err
	}
	h, err := openReparse(link, windows.GENERIC_WRITE)
	if err != nil {
		os.Remove(link)
		return err
	}

	sub := utf16.Encode([]rune(`\??\` + target))
	prn := utf16.Encode([]rune(target))
	subBytes := len(sub) * 2
	prnBytes := len(prn) * 2
	pathBuf := 8 + subBytes + 2 + prnBytes + 2 // header of MountPointReparseBuffer + strings with NULs
	b := make([]byte, 8+pathBuf)
	binary.LittleEndian.PutUint32(b[0:], ioReparseTagMountPt)
	binary.LittleEndian.PutUint16(b[4:], uint16(pathBuf))
	binary.LittleEndian.PutUint16(b[8:], 0)                   // SubstituteNameOffset
	binary.LittleEndian.PutUint16(b[10:], uint16(subBytes))   // SubstituteNameLength
	binary.LittleEndian.PutUint16(b[12:], uint16(subBytes+2)) // PrintNameOffset
	binary.LittleEndian.PutUint16(b[14:], uint16(prnBytes))   // PrintNameLength
	off := 16
	for _, c := range sub {
		binary.LittleEndian.PutUint16(b[off:], c)
		off += 2
	}
	off += 2
	for _, c := range prn {
		binary.LittleEndian.PutUint16(b[off:], c)
		off += 2
	}
	var n uint32
	err = windows.DeviceIoControl(h, fsctlSetReparsePoint, &b[0], uint32(len(b)), nil, 0, &n, nil)
	windows.CloseHandle(h)
	if err != nil {
		os.Remove(link)
		return fmt.Errorf("set junction: %w", err)
	}
	return nil
}

package main

// The games' own icons for the launcher's Games page: the icon Windows shows for each game's
// program, read from its exe (as Explorer does) and handed to the page as a PNG.

import (
	"bytes"
	"errors"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

// gameExe: where each game's program is, given its folder
func gameExe(id, dir string) string {
	switch id {
	case "etterna":
		return filepath.Join(dir, "Program", "Etterna.exe")
	case "osu":
		return filepath.Join(dir, "osu!.exe")
	case "quaver":
		return filepath.Join(dir, "Quaver.exe")
	case "qwilight":
		return filepath.Join(dir, "Qwilight.exe")
	}
	return ""
}

// exeIconPNG reads the icon of a program at the given size (as a PNG with transparency)
func exeIconPNG(exe string, size int) ([]byte, error) {
	if exe == "" {
		return nil, errors.New("no program")
	}
	if _, err := os.Stat(exe); err != nil {
		return nil, err
	}
	user32 := windows.NewLazySystemDLL("user32.dll")
	gdi32 := windows.NewLazySystemDLL("gdi32.dll")
	p, _ := syscall.UTF16PtrFromString(exe)
	var icon windows.Handle
	n, _, _ := user32.NewProc("PrivateExtractIconsW").Call(uintptr(unsafe.Pointer(p)), 0, uintptr(size), uintptr(size), uintptr(unsafe.Pointer(&icon)), 0, 1, 0)
	if n == 0 || icon == 0 {
		return nil, errors.New("no icon")
	}
	defer user32.NewProc("DestroyIcon").Call(uintptr(icon))
	var ii struct {
		Icon     int32
		XHotspot uint32
		YHotspot uint32
		Mask     windows.Handle
		Color    windows.Handle
	}
	if r, _, _ := user32.NewProc("GetIconInfo").Call(uintptr(icon), uintptr(unsafe.Pointer(&ii))); r == 0 {
		return nil, errors.New("icon info")
	}
	deleteObject := gdi32.NewProc("DeleteObject")
	if ii.Mask != 0 {
		defer deleteObject.Call(uintptr(ii.Mask))
	}
	if ii.Color == 0 {
		return nil, errors.New("monochrome icon")
	}
	defer deleteObject.Call(uintptr(ii.Color))
	type bitmap struct {
		Type, Width, Height, WidthBytes int32
		Planes, BitsPixel               uint16
		Bits                            uintptr
	}
	var bm bitmap
	if r, _, _ := gdi32.NewProc("GetObjectW").Call(uintptr(ii.Color), unsafe.Sizeof(bm), uintptr(unsafe.Pointer(&bm))); r == 0 {
		return nil, errors.New("bitmap")
	}
	w, h := int(bm.Width), int(bm.Height)
	if w <= 0 || h <= 0 || w > 1024 || h > 1024 {
		return nil, errors.New("bitmap size")
	}
	type bitmapInfoHeader struct {
		Size          uint32
		Width, Height int32
		Planes, Bits  uint16
		Compression   uint32
		SizeImage     uint32
		XPels, YPels  int32
		ClrUsed       uint32
		ClrImportant  uint32
	}
	dc, _, _ := user32.NewProc("GetDC").Call(0)
	defer user32.NewProc("ReleaseDC").Call(0, dc)
	read := func(hbm windows.Handle) ([]byte, bool) {
		bi := bitmapInfoHeader{Size: 40, Width: int32(w), Height: -int32(h), Planes: 1, Bits: 32} // (top-down)
		buf := make([]byte, w*h*4)
		r, _, _ := gdi32.NewProc("GetDIBits").Call(dc, uintptr(hbm), 0, uintptr(h), uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&bi)), 0)
		return buf, r != 0
	}
	col, ok := read(ii.Color)
	if !ok {
		return nil, errors.New("pixels")
	}
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	hasAlpha := false
	for i := 0; i < w*h; i++ {
		b, g, r, a := col[i*4], col[i*4+1], col[i*4+2], col[i*4+3]
		if a != 0 {
			hasAlpha = true
		}
		img.Pix[i*4], img.Pix[i*4+1], img.Pix[i*4+2], img.Pix[i*4+3] = r, g, b, a
	}
	if !hasAlpha {
		// (an icon without an alpha channel: its mask says what's see-through)
		for i := 0; i < w*h; i++ {
			img.Pix[i*4+3] = 255
		}
		if ii.Mask != 0 {
			if mask, ok := read(ii.Mask); ok {
				for i := 0; i < w*h; i++ {
					if mask[i*4] != 0 {
						img.Pix[i*4+3] = 0
					}
				}
			}
		}
	}
	var out bytes.Buffer
	if err := png.Encode(&out, img); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

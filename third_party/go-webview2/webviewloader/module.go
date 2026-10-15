// Package webviewloader calls WebView2Loader.dll, which must be next to the program.
// (VSRG Hub's copy of go-webview2: the original can also load an embedded copy of the DLL from
// memory when the file is missing; that is left out here, since antivirus programs flag
// programs that load DLLs from memory.)
package webviewloader

import (
	"fmt"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	nativeModule                                       = windows.NewLazyDLL("WebView2Loader")
	nativeCreate                                       = nativeModule.NewProc("CreateCoreWebView2EnvironmentWithOptions")
	nativeCompareBrowserVersions                       = nativeModule.NewProc("CompareBrowserVersions")
	nativeGetAvailableCoreWebView2BrowserVersionString = nativeModule.NewProc("GetAvailableCoreWebView2BrowserVersionString")
)

func load(p *windows.LazyProc) error {
	if err := nativeModule.Load(); err != nil {
		return fmt.Errorf("WebView2Loader.dll couldn't be loaded: %w", err)
	}
	return p.Find()
}

// CompareBrowserVersions compares two WebView2 versions: -1, 0 or 1.
func CompareBrowserVersions(v1 string, v2 string) (int, error) {
	_v1, err := windows.UTF16PtrFromString(v1)
	if err != nil {
		return 0, err
	}
	_v2, err := windows.UTF16PtrFromString(v2)
	if err != nil {
		return 0, err
	}
	if err := load(nativeCompareBrowserVersions); err != nil {
		return 0, err
	}
	var result int
	_, _, err = nativeCompareBrowserVersions.Call(uintptr(unsafe.Pointer(_v1)), uintptr(unsafe.Pointer(_v2)), uintptr(unsafe.Pointer(&result)))
	if err != windows.ERROR_SUCCESS {
		return result, err
	}
	return result, nil
}

// GetInstalledVersion returns the installed WebView2 runtime's version ("" when there is none).
func GetInstalledVersion() (string, error) {
	if err := load(nativeGetAvailableCoreWebView2BrowserVersionString); err != nil {
		return "", err
	}
	var result *uint16
	hr, _, _ := nativeGetAvailableCoreWebView2BrowserVersionString.Call(uintptr(unsafe.Pointer(nil)), uintptr(unsafe.Pointer(&result)))
	defer windows.CoTaskMemFree(unsafe.Pointer(result))
	if hr != uintptr(windows.S_OK) {
		if hr&0xFFFF == uintptr(windows.ERROR_FILE_NOT_FOUND) {
			return "", nil
		}
		return "", fmt.Errorf("GetAvailableCoreWebView2BrowserVersionString returned HRESULT 0x%X", hr)
	}
	return windows.UTF16PtrToString(result), nil
}

// CreateCoreWebView2EnvironmentWithOptions calls the DLL's function of that name.
func CreateCoreWebView2EnvironmentWithOptions(browserExecutableFolder, userDataFolder *uint16, environmentOptions uintptr, environmentCompletedHandle uintptr) (uintptr, error) {
	if err := load(nativeCreate); err != nil {
		return 0, err
	}
	res, _, _ := nativeCreate.Call(uintptr(unsafe.Pointer(browserExecutableFolder)), uintptr(unsafe.Pointer(userDataFolder)), environmentOptions, environmentCompletedHandle)
	return res, nil
}

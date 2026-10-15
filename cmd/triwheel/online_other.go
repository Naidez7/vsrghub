//go:build !windows

package main

func protectData(b []byte) ([]byte, error)   { return b, nil }
func unprotectData(b []byte) ([]byte, error) { return b, nil }

func windowsVersion() string { return "(not Windows)" }

func startTray(tip func() string) func() { return func() {} }
func trayTip(data string) string         { return "" }

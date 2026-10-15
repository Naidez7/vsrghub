//go:build !windows

package main

func askYesNo(title, text string) bool { return false }
func showMessage(title, text string)   {}

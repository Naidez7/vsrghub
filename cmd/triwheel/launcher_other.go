//go:build !windows

package main

import "os/exec"

// (the launcher window is Windows only)
func runLauncher(l *launch) (*exec.Cmd, func(), bool) { return nil, nil, false }

func launcherUnavailable() {}

//go:build !windows

package main

func registryOsuDirs() []string   { return nil }
func registrySteamDirs() []string { return nil }
func driveRoots() []string        { return nil }

func registryEtternaDirs() []string { return nil }

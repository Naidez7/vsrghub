//go:build !windows

package main

import (
	"fmt"
	"io"
)

func discordPipe() (io.ReadWriteCloser, error) { return nil, fmt.Errorf("not Windows") }

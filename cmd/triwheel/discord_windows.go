package main

import (
	"fmt"
	"io"
	"os"
)

// discordPipe opens Discord's IPC pipe (the first of discord-ipc-0..9 that answers)
func discordPipe() (io.ReadWriteCloser, error) {
	for i := 0; i < 10; i++ {
		f, err := os.OpenFile(fmt.Sprintf(`\\.\pipe\discord-ipc-%d`, i), os.O_RDWR, 0)
		if err == nil {
			return f, nil
		}
	}
	return nil, fmt.Errorf("Discord isn't running")
}

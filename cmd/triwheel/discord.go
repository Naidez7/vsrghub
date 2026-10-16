package main

// Discord's "Playing VSRG Hub" (rich presence) while the game runs: what the song select writes to
// online/status.txt (28 VSRG Hub status.lua) goes to Discord through its local IPC pipe, with no
// library: a handshake frame, then an activity frame whenever the status changes. Off when there is
// no Discord running, or when turned off on the Options page (triwheel-state.json: discordOff).

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// discordAppID is VSRG Hub's application at discord.com/developers (its art assets: "logo").
const discordAppID = "1560226399422259262"

type discordConn struct {
	rw io.ReadWriteCloser
}

func (c *discordConn) send(op uint32, v any) error {
	b, _ := json.Marshal(v)
	hdr := make([]byte, 8)
	binary.LittleEndian.PutUint32(hdr, op)
	binary.LittleEndian.PutUint32(hdr[4:], uint32(len(b)))
	if _, err := c.rw.Write(append(hdr, b...)); err != nil {
		return err
	}
	// (the answer, read and dropped; the pipe is a message pipe, so one read gets one frame)
	buf := make([]byte, 1<<16)
	c.rw.Read(buf)
	return nil
}

func discordDial() (*discordConn, error) {
	if discordAppID == "" {
		return nil, fmt.Errorf("no application id")
	}
	rw, err := discordPipe()
	if err != nil {
		return nil, err
	}
	c := &discordConn{rw}
	if err := c.send(0, map[string]any{"v": 1, "client_id": discordAppID}); err != nil {
		rw.Close()
		return nil, err
	}
	return c, nil
}

// launcherPresence: the activity while the launcher is open: who you are on the rankings (me.txt)
func launcherPresence(data string, since int64) map[string]any {
	a := map[string]any{"details": "In the launcher", "timestamps": map[string]any{"start": since},
		"assets": map[string]any{"large_image": "logo", "large_text": "VSRG Hub"}}
	if b, err := os.ReadFile(filepath.Join(onlineDir(data), "me.txt")); err == nil {
		f := strings.Split(strings.TrimSpace(string(b)), "\t")
		if len(f) >= 5 && f[0] != "" {
			var parts []string
			if f[3] != "0" && f[3] != "" {
				parts = append(parts, "#"+f[3]+" in 4K ("+f[1]+")")
			}
			if f[4] != "0" && f[4] != "" {
				parts = append(parts, "#"+f[4]+" in 7K ("+f[2]+")")
			}
			state := f[0]
			if len(parts) > 0 {
				state += " · " + strings.Join(parts, " · ")
			}
			a["state"] = state
		}
	}
	return a
}

// presenceOf: the activity for a status line "what\ttitle\tartist\tdifficulty\tkeys\trate"
func presenceOf(line string, since int64) map[string]any {
	f := strings.Split(strings.TrimRight(line, "\r\n"), "\t")
	for len(f) < 6 {
		f = append(f, "")
	}
	what, title, artist, diff, keys, rate := f[0], f[1], f[2], f[3], f[4], f[5]
	song := title
	if artist != "" {
		song = artist + " - " + title
	}
	chart := diff
	if keys != "" {
		chart = strings.TrimSpace(diff + " · " + keys + "K")
		chart = strings.TrimPrefix(chart, "· ")
	}
	if rate != "" && rate != "1.00" {
		chart += " · " + strings.TrimSuffix(rate, "0") + "x"
	}
	details, state := "In the menus", ""
	switch what {
	case "select":
		details, state = "Picking a song", song
	case "play":
		details, state = "Playing "+song, chart
	case "practice":
		details, state = "Practicing "+song, chart
	case "results":
		details, state = "Results: "+song, chart
	case "multi":
		details = "In a multiplayer lobby"
	}
	cut := func(s string, n int) string {
		r := []rune(s)
		if len(r) > n {
			return string(r[:n-1]) + "…"
		}
		return s
	}
	a := map[string]any{"details": cut(details, 120), "timestamps": map[string]any{"start": since},
		"assets": map[string]any{"large_image": "logo", "large_text": "VSRG Hub"}}
	if state != "" {
		a["state"] = cut(state, 120)
	}
	return a
}

// startPresence keeps Discord told while the game runs (inGame), or while the launcher is open; the
// returned function stops it (and clears the presence).
// (one presence at a time: the game's replaces the launcher's while the game runs, or Discord
// keeps showing whichever connected first)
var presenceMu sync.Mutex
var presenceCur chan struct{}

func startPresence(data string, inGame bool) func() {
	stop := make(chan struct{})
	if data == "" || discordAppID == "" || loadState(data).DiscordOff {
		return func() {}
	}
	presenceMu.Lock()
	if presenceCur != nil {
		close(presenceCur)
	}
	presenceCur = stop
	presenceMu.Unlock()
	stopIt := func() {
		presenceMu.Lock()
		defer presenceMu.Unlock()
		if presenceCur == stop {
			close(stop)
			presenceCur = nil
		}
	}
	go func() {
		var c *discordConn
		var lastTry time.Time
		last := ""
		since := time.Now().Unix()
		statusFile := filepath.Join(onlineDir(data), "status.txt")
		if inGame {
			os.Remove(statusFile)
		}
		t := time.NewTicker(3 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-stop:
				if c != nil {
					c.send(1, map[string]any{"cmd": "SET_ACTIVITY", "args": map[string]any{"pid": os.Getpid()}, "nonce": "bye"})
					c.rw.Close()
				}
				return
			case <-t.C:
			}
			if c == nil {
				if time.Since(lastTry) < 30*time.Second {
					continue
				}
				lastTry = time.Now()
				cc, err := discordDial()
				if err != nil {
					continue
				}
				c = cc
				last = ""
				logf("discord: presence on")
			}
			var line string
			var activity map[string]any
			if inGame {
				b, _ := os.ReadFile(statusFile)
				line = strings.TrimSpace(string(b))
				if line == "" {
					line = "menu"
				}
				activity = presenceOf(line, since)
			} else {
				activity = launcherPresence(data, since)
				line = fmt.Sprint(activity["state"])
			}
			if line == last {
				continue
			}
			err := c.send(1, map[string]any{"cmd": "SET_ACTIVITY", "nonce": fmt.Sprint(time.Now().UnixNano()),
				"args": map[string]any{"pid": os.Getpid(), "activity": activity}})
			if err != nil {
				logf("discord: %v (trying again later)", err)
				c.rw.Close()
				c = nil
				continue
			}
			last = line
		}
	}()
	return stopIt
}

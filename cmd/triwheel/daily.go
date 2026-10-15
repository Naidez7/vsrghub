package main

// The daily challenge: one chart a day for everyone (4K and 7K each; the server picks it:
// daily_chart), its board for the day and the last days' winners. The launcher shows it, and
// writes today's charts for the game (online/daily.txt: "keys<TAB>chart key<TAB>title<TAB>artist
// <TAB>chart name<TAB>msd" a line each) and, on "Play it", where song select should jump
// (online/jump.txt: the chart key).

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type dailyChart struct {
	ChartKey   string  `json:"chart_key"`
	SongTitle  string  `json:"song_title"`
	SongArtist string  `json:"song_artist"`
	ChartName  string  `json:"chart_name"`
	MSD        float64 `json:"msd"`
	Players    int     `json:"players"`
}

func dailyDay() string { return time.Now().UTC().Format("2006-01-02") }

// onlineDaily: today's chart, its board and the last days for one key count
func onlineDaily(keys int) (map[string]any, error) {
	day := dailyDay()
	var charts []dailyChart
	if err := onlineCall("POST", "/rest/v1/rpc/daily_chart", map[string]any{"day": day, "k": keys}, "", &charts); err != nil {
		return nil, err
	}
	out := map[string]any{"day": day, "keys": keys}
	if len(charts) == 0 {
		return out, nil
	}
	out["chart"] = charts[0]
	var board []map[string]any
	onlineCall("POST", "/rest/v1/rpc/daily_board", map[string]any{"day": day, "k": keys}, "", &board)
	for _, r := range board {
		id, _ := r["user_id"].(string)
		av, _ := r["avatar"].(float64)
		ext, _ := r["avatar_ext"].(string)
		r["picture"] = avatarURL(id, int(av), ext)
	}
	out["board"] = board
	var hist []map[string]any
	onlineCall("POST", "/rest/v1/rpc/daily_history", map[string]any{"days": 14, "k": keys}, "", &hist)
	out["history"] = hist
	if s, err := onlineToken(); err == nil {
		out["me"] = s.UserID
	}
	// the time left in the day (UTC)
	now := time.Now().UTC()
	out["left"] = int(time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC).Sub(now).Seconds())
	return out, nil
}

// writeDaily: today's charts for the game
func writeDaily(data string) {
	var sb strings.Builder
	for _, k := range []int{4, 7} {
		var charts []dailyChart
		if onlineCall("POST", "/rest/v1/rpc/daily_chart", map[string]any{"day": dailyDay(), "k": k}, "", &charts) != nil || len(charts) == 0 {
			continue
		}
		c := charts[0]
		clean := func(s string) string { return strings.NewReplacer("\t", " ", "\n", " ", "\r", " ").Replace(s) }
		fmt.Fprintf(&sb, "%d\t%s\t%s\t%s\t%s\t%.2f\n", k, c.ChartKey, clean(c.SongTitle), clean(c.SongArtist), clean(c.ChartName), c.MSD)
	}
	os.MkdirAll(onlineDir(data), 0o755)
	os.WriteFile(filepath.Join(onlineDir(data), "daily.txt"), []byte(sb.String()), 0o644)
}

// writeJump: where song select should go next
func writeJump(data, chart string) {
	os.MkdirAll(onlineDir(data), 0o755)
	os.WriteFile(filepath.Join(onlineDir(data), "jump.txt"), []byte(chart+"\n"), 0o644)
}

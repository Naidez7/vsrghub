package main

// Ranking notices: "PraileX passed you in 4K: you're #3 now". The launcher keeps the last ranking it
// saw (who was above you) in notices.json and, each time it looks again, tells you who got past.
// New notices go to the launcher's Online page and, while the game runs, to online/notice.txt, which
// the song select shows (28 VSRG Hub notices.lua).

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type notice struct {
	When string `json:"when"`
	Keys int    `json:"keys"`
	Text string `json:"text"`
}

type noticeState struct {
	User     string                     `json:"user"`
	Above    map[string]map[string]bool `json:"above"` // keys ("4") → the ids above you
	Place    map[string]int             `json:"place"`
	List     []notice                   `json:"list"`     // newest first
	FirstsAt string                     `json:"firstsAt"` // when the charts you were #1 on were last looked at
}

var noticesMu sync.Mutex

func noticesPath(data string) string { return filepath.Join(onlineDir(data), "notices.json") }

func loadNotices(data string) noticeState {
	var st noticeState
	readFileJSON(noticesPath(data), &st)
	if st.Above == nil {
		st.Above = map[string]map[string]bool{}
	}
	if st.Place == nil {
		st.Place = map[string]int{}
	}
	return st
}

// checkNotices looks at the rankings and returns the new notices (none the first time, when there
// is nothing to compare with). game: also write them for the running game.
func checkNotices(data string, game bool) []notice {
	s, err := onlineToken()
	if err != nil || s.Username == "" {
		return nil
	}
	noticesMu.Lock()
	defer noticesMu.Unlock()
	st := loadNotices(data)
	fresh := st.User != s.UserID
	if fresh {
		st = noticeState{User: s.UserID, Above: map[string]map[string]bool{}, Place: map[string]int{}}
	}
	var out []notice
	for _, keys := range []int{4, 7} {
		rows, err := onlineRankings(keys, "overall", 200, 0)
		if err != nil {
			continue
		}
		k := fmt.Sprint(keys)
		me := -1
		for i, r := range rows {
			if r.UserID == s.UserID {
				me = i
				break
			}
		}
		if me < 0 {
			// (not on the first 200, or no plays: nothing to compare)
			delete(st.Above, k)
			delete(st.Place, k)
			continue
		}
		above := map[string]bool{}
		var passed []string
		for _, r := range rows[:me] {
			above[r.UserID] = true
			if old, had := st.Above[k]; !fresh && had && !old[r.UserID] {
				passed = append(passed, r.Username)
			}
		}
		place := rows[me].Place
		if !fresh {
			if _, had := st.Place[k]; had {
				sort.Strings(passed)
				switch {
				case len(passed) == 1:
					out = append(out, notice{Keys: keys, Text: fmt.Sprintf("%s passed you in %dK: you're #%d now", passed[0], keys, place)})
				case len(passed) > 1:
					out = append(out, notice{Keys: keys, Text: fmt.Sprintf("%s passed you in %dK: you're #%d now", strings.Join(passed[:len(passed)-1], ", ")+" and "+passed[len(passed)-1], keys, place)})
				case place < st.Place[k]:
					out = append(out, notice{Keys: keys, Text: fmt.Sprintf("You're #%d in %dK now (up from #%d)", place, keys, st.Place[k])})
				}
			}
		}
		st.Above[k] = above
		st.Place[k] = place
	}
	// the charts where someone took #1 from you since the last look
	nowT := time.Now()
	if st.FirstsAt != "" {
		var lost []struct {
			Title string  `json:"song_title"`
			Name  string  `json:"chart_name"`
			Keys  int     `json:"keys"`
			By    string  `json:"by_name"`
			Their float64 `json:"their_ssr"`
			Mine  float64 `json:"my_ssr"`
		}
		if err := onlineCall("POST", "/rest/v1/rpc/lost_firsts", map[string]any{"player": s.UserID, "since": st.FirstsAt}, "", &lost); err == nil {
			for i, l := range lost {
				if i >= 10 {
					break
				}
				name := l.Title
				if l.Name != "" {
					name += " · " + l.Name
				}
				out = append(out, notice{Keys: l.Keys, Text: fmt.Sprintf("%s took #1 on %s (%dK) from you: %.2f to your %.2f", l.By, name, l.Keys, l.Their, l.Mine)})
			}
		}
	}
	st.FirstsAt = nowT.Format(time.RFC3339)
	now := nowT.Format(time.RFC3339)
	for i := range out {
		out[i].When = now
	}
	st.List = append(append([]notice{}, out...), st.List...)
	if len(st.List) > 40 {
		st.List = st.List[:40]
	}
	b, _ := json.Marshal(st)
	os.MkdirAll(onlineDir(data), 0o755)
	os.WriteFile(noticesPath(data), b, 0o644)
	if game && len(out) > 0 {
		var sb strings.Builder
		if old, err := os.ReadFile(filepath.Join(onlineDir(data), "notice.txt")); err == nil {
			sb.Write(old)
		}
		for _, n := range out {
			sb.WriteString(n.Text + "\n")
		}
		os.WriteFile(filepath.Join(onlineDir(data), "notice.txt"), []byte(sb.String()), 0o644)
	}
	for _, n := range out {
		logf("notice: %s", n.Text)
	}
	return out
}

// noticeList: the notices kept (newest first)
func noticeList(data string) []notice {
	noticesMu.Lock()
	defer noticesMu.Unlock()
	return loadNotices(data).List
}

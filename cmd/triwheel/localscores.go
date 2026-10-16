package main

// Your osu! and Quaver plays as Etterna's own local scores. Once the game has rated a play (28 VSRG
// Hub osu plays.lua: the score's JSON in online/outbox, then sent/ or refused/), the launcher writes
// it into the profile's Etterna.xml (Save/LocalProfiles/<id>/) the way Etterna saves a score, with
// its replay (online/osu/replays/<key>, written with the job) in Save/ReplaysV2: the next start
// shows it on the local ranking, the profile, its results screen and its replay. Etterna works
// out the skillset ratings itself at that start (the score says it was rated by calc version 0).
//
// Only with the game closed: Etterna reads the profile as it starts and writes it as it ends.
// Each write first keeps a copy of the file (Save/VSRGHub/backup/). online/osu/local.txt lists the
// score keys written, so each goes in once.

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/beevik/etree"
)

// (Etterna's own marker for scores already uploaded to EtternaOnline: these must never be, so
// they carry it from the start)
const etternaOnlineURL = "https://api.etternaonline.com"

func profileXML(etterna string) string {
	id := strings.TrimSpace(readPrefs(etterna)["DefaultLocalProfileIDP1"])
	if id == "" {
		id = "00000000"
	}
	return filepath.Join(etterna, "Save", "LocalProfiles", id, "Etterna.xml")
}

// the score JSON the game wrote (28 VSRG Hub online.lua's scoreJSON, with the source and the
// judgements): what Etterna's score node needs
type sentScore struct {
	Key       string  `json:"score_key"`
	Chart     string  `json:"chart_key"`
	Keys      int     `json:"keys"`
	Rate      float64 `json:"rate"`
	Wife      float64 `json:"wife"`
	MaxCombo  int     `json:"max_combo"`
	Modifiers string  `json:"modifiers"`
	Title     string  `json:"song_title"`
	Artist    string  `json:"song_artist"`
	ChartName string  `json:"chart_name"`
	PlayedAt  string  `json:"played_at"`
	Source    string  `json:"source"`
	Marv      int     `json:"marvelous"`
	Perf      int     `json:"perfect"`
	Great     int     `json:"great"`
	Good      int     `json:"good"`
	Bad       int     `json:"bad"`
	Miss      int     `json:"miss"`
	HoldsNG   int     `json:"holds_ng"`
	Mines     int     `json:"mines_hit"`
	Failed    bool    `json:"failed"`
}

func localScoresPath(data string) string { return filepath.Join(onlineDir(data), "osu", "local.txt") }

func loadLocalScores(data string) map[string]bool {
	done := map[string]bool{}
	b, err := os.ReadFile(localScoresPath(data))
	if err != nil {
		return done
	}
	for _, l := range strings.Split(string(b), "\n") {
		if l = strings.TrimSpace(l); l != "" {
			done[l] = true
		}
	}
	return done
}

// injectLocalScores writes the rated osu! / Quaver plays not yet in the profile. It returns how
// many it wrote.
var injectMu sync.Mutex

func injectLocalScores(etterna, data string) (int, error) {
	if etterna == "" || data == "" {
		return 0, nil
	}
	injectMu.Lock()
	defer injectMu.Unlock()
	done := loadLocalScores(data)
	var list []sentScore
	for _, sub := range []string{"sent", "refused", "outbox"} {
		entries, _ := os.ReadDir(filepath.Join(onlineDir(data), sub))
		for _, e := range entries {
			name := e.Name()
			if e.IsDir() || !strings.HasSuffix(name, ".json") {
				continue
			}
			key := strings.TrimSuffix(name, ".json")
			if done[key] || !(strings.HasPrefix(key, "O") || strings.HasPrefix(key, "Q")) {
				continue
			}
			if _, err := os.Stat(filepath.Join(onlineDir(data), "osu", "replays", key)); err != nil {
				continue // (rated before the replays were kept: "Send my osu! / Quaver plays again" redoes it)
			}
			b, err := os.ReadFile(filepath.Join(onlineDir(data), sub, name))
			if err != nil {
				continue
			}
			var s sentScore
			if json.Unmarshal(b, &s) != nil || s.Key != key || s.Chart == "" || s.Failed {
				continue
			}
			list = append(list, s)
		}
	}
	if len(list) == 0 {
		return 0, nil
	}
	xmlPath := profileXML(etterna)
	raw, err := os.ReadFile(xmlPath)
	if err != nil {
		return 0, fmt.Errorf("the Etterna profile (%s): %w", xmlPath, err)
	}
	gz := len(raw) > 2 && raw[0] == 0x1f && raw[1] == 0x8b
	content := raw
	if gz {
		r, err := gzip.NewReader(bytes.NewReader(raw))
		if err != nil {
			return 0, err
		}
		if content, err = io.ReadAll(r); err != nil {
			return 0, err
		}
	}
	doc := etree.NewDocument()
	if err := doc.ReadFromBytes(content); err != nil {
		return 0, fmt.Errorf("the Etterna profile couldn't be read: %w", err)
	}
	stats := doc.SelectElement("Stats")
	if stats == nil {
		return 0, errors.New("the Etterna profile has no Stats")
	}
	scores := stats.SelectElement("PlayerScores")
	if scores == nil {
		scores = stats.CreateElement("PlayerScores")
	}
	// (the file as it was, before anything changes)
	backupDir := filepath.Join(data, "backup")
	os.MkdirAll(backupDir, 0o755)
	os.WriteFile(filepath.Join(backupDir, "Etterna.xml."+time.Now().Format("20060102-150405")), raw, 0o644)
	pruneBackups(backupDir, 5)

	replayDir := filepath.Join(etterna, "Save", "ReplaysV2")
	os.MkdirAll(replayDir, 0o755)
	var written []string
	for _, s := range list {
		chart := findAttr(scores, "Chart", "Key", s.Chart)
		if chart == nil {
			chart = scores.CreateElement("Chart")
			chart.CreateAttr("Key", s.Chart)
			chart.CreateAttr("Pack", "")
			chart.CreateAttr("Song", s.Title)
			chart.CreateAttr("Steps", "Edit")
		}
		rate := fmt.Sprintf("%.3f", s.Rate)
		at := findAttr(chart, "ScoresAt", "Rate", rate)
		if at == nil {
			at = chart.CreateElement("ScoresAt")
			at.CreateAttr("PBKey", s.Key)
			at.CreateAttr("BestGrade", etternaGrade(s.Wife))
			at.CreateAttr("Rate", rate)
		}
		if findAttr(at, "Score", "Key", s.Key) != nil {
			written = append(written, s.Key) // (there already: noted, not written twice)
			continue
		}
		replay, err := os.ReadFile(filepath.Join(onlineDir(data), "osu", "replays", s.Key))
		if err != nil || len(replay) == 0 {
			continue
		}
		if err := os.WriteFile(filepath.Join(replayDir, s.Key), replay, 0o644); err != nil {
			continue
		}
		at.AddChild(scoreNode(s, replay))
		written = append(written, s.Key)
	}
	if len(written) == 0 {
		return 0, nil
	}
	doc.Indent(0)
	out, err := doc.WriteToBytes()
	if err != nil {
		return 0, err
	}
	if gz {
		var zb bytes.Buffer
		w := gzip.NewWriter(&zb)
		w.Write(out)
		w.Close()
		out = zb.Bytes()
	}
	tmp := xmlPath + ".vsrghub.tmp"
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return 0, err
	}
	if err := os.Rename(tmp, xmlPath); err != nil {
		os.Remove(tmp)
		return 0, err
	}
	// noted (the ones Etterna had already too)
	f, err := os.OpenFile(localScoresPath(data), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err == nil {
		for _, k := range written {
			fmt.Fprintln(f, k)
		}
		f.Close()
	}
	logf("local scores: %d osu! / Quaver plays written to the Etterna profile", len(written))
	return len(written), nil
}

func findAttr(parent *etree.Element, tag, attr, value string) *etree.Element {
	for _, e := range parent.SelectElements(tag) {
		if e.SelectAttrValue(attr, "") == value {
			return e
		}
	}
	return nil
}

// etternaGrade: Etterna's grade for a Wife% (its GetGradeFromPercent, without the mid grades)
func etternaGrade(wife float64) string {
	w := wife / 100
	switch {
	case w >= 0.999935:
		return "Tier01"
	case w >= 0.99955:
		return "Tier04"
	case w >= 0.997:
		return "Tier07"
	case w >= 0.93:
		return "Tier10"
	case w >= 0.80:
		return "Tier13"
	case w >= 0.70:
		return "Tier14"
	case w >= 0.60:
		return "Tier15"
	}
	return "Tier16"
}

// scoreNode: the Score element as Etterna's HighScore::CreateEttNode writes it
func scoreNode(s sentScore, replay []byte) *etree.Element {
	e := etree.NewElement("Score")
	e.CreateAttr("Key", s.Key)
	add := func(name, value string) { e.CreateElement(name).SetText(value) }
	add("SSRCalcVersion", "0") // (Etterna rates it at its next start)
	add("Grade", etternaGrade(s.Wife))
	add("WifeScore", fmt.Sprintf("%.6f", s.Wife/100))
	add("SSRNormPercent", fmt.Sprintf("%.6f", s.Wife/100))
	add("JudgeScale", "1.000000")
	add("NoChordCohesion", "1")
	add("EtternaValid", "1")
	add("PlayedSeconds", "0")
	add("MaxCombo", fmt.Sprint(s.MaxCombo))
	src := "osu!"
	switch s.Source {
	case "lazer":
		src = "osu!lazer"
	case "quaver":
		src = "Quaver"
	}
	add("Modifiers", src)
	add("MachineGuid", "")
	add("DateTime", etternaDate(s.PlayedAt))
	add("TopScore", "0")
	servs := e.CreateElement("Servs")
	servs.CreateElement("server").SetText(etternaOnlineURL)
	for _, name := range []string{"TapNoteScores", "TNSNormalized"} {
		t := e.CreateElement(name)
		for _, v := range []struct {
			n string
			v int
		}{{"W1", s.Marv}, {"W2", s.Perf}, {"W3", s.Great}, {"W4", s.Good}, {"W5", s.Bad}, {"Miss", s.Miss}, {"HitMine", s.Mines}, {"AvoidMine", 0}} {
			t.CreateElement(v.n).SetText(fmt.Sprint(v.v))
		}
	}
	holds := 0
	for _, line := range strings.Split(string(replay), "\n") {
		if f := strings.Fields(line); len(f) == 4 && f[3] == "2" {
			holds++ // (a hold's head: "row offset track 2")
		}
	}
	h := e.CreateElement("HoldNoteScores")
	h.CreateElement("LetGo").SetText(fmt.Sprint(s.HoldsNG))
	h.CreateElement("Held").SetText(fmt.Sprint(max(0, holds-s.HoldsNG)))
	h.CreateElement("Missed").SetText("0")
	v := e.CreateElement("ValidationKeys")
	v.CreateElement("Brittle").SetText("")
	v.CreateElement("Weak").SetText("")
	add("wv", "3")
	return e
}

// etternaDate: the play's moment as Etterna writes it (the player's local clock)
func etternaDate(playedAt string) string {
	t, err := time.Parse(time.RFC3339, playedAt)
	if err != nil {
		t = time.Now()
	} else {
		t = t.Local()
	}
	return t.Format("2006-01-02 15:04:05")
}

func pruneBackups(dir string, keep int) {
	entries, _ := os.ReadDir(dir)
	var names []string
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "Etterna.xml.") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	for len(names) > keep {
		os.Remove(filepath.Join(dir, names[0]))
		names = names[1:]
	}
}

package main

// Reads osu!mania beatmaps (.osu) from the player's own osu! Songs folder and
// hands them to the same .sm writer as Quaver maps.

import (
	"bufio"
	"bytes"
	"fmt"
	"math"
	"os"
	"strconv"
	"strings"
)

func parseOsu(path string) (*quaMap, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	b = bytes.TrimPrefix(b, []byte("\xef\xbb\xbf"))
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(make([]byte, 1024*1024), 16*1024*1024)
	section := ""
	kv := map[string]map[string]string{}
	var timing, hits [][]string
	var bg string
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "//") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = line[1 : len(line)-1]
			continue
		}
		switch section {
		case "General", "Metadata", "Difficulty":
			k, v, ok := strings.Cut(line, ":")
			if ok {
				if kv[section] == nil {
					kv[section] = map[string]string{}
				}
				kv[section][strings.TrimSpace(k)] = strings.TrimSpace(v)
			}
			if section == "General" && strings.TrimSpace(k) == "Mode" && strings.TrimSpace(v) != "3" {
				return nil, nil // not osu!mania
			}
		case "Events":
			f := strings.Split(line, ",")
			if bg == "" && len(f) >= 3 && (f[0] == "0" || f[0] == "Background") && f[1] == "0" {
				bg = strings.Trim(f[2], `"`)
			}
		case "TimingPoints":
			timing = append(timing, strings.Split(line, ","))
		case "HitObjects":
			hits = append(hits, strings.Split(line, ","))
		}
	}
	gen, meta, diff := kv["General"], kv["Metadata"], kv["Difficulty"]
	if gen["Mode"] != "3" {
		return nil, nil
	}
	keys, _ := strconv.ParseFloat(diff["CircleSize"], 64)
	q := &quaMap{source: "osu", file: baseName(path)}
	q.Mode = fmt.Sprintf("Keys%d", int(keys))
	q.AudioFile = gen["AudioFilename"]
	if p, err := strconv.ParseFloat(gen["PreviewTime"], 64); err == nil && p > 0 {
		q.SongPreviewTime = p
	}
	q.BackgroundFile = bg
	q.Title = firstNonEmpty(meta["TitleUnicode"], meta["Title"])
	q.Artist = firstNonEmpty(meta["ArtistUnicode"], meta["Artist"])
	q.TitleTranslit, q.ArtistTranslit = meta["Title"], meta["Artist"]
	q.Creator = meta["Creator"]
	q.DifficultyName = meta["Version"]
	for _, f := range timing {
		if len(f) < 2 {
			continue
		}
		t, err1 := strconv.ParseFloat(strings.TrimSpace(f[0]), 64)
		bl, err2 := strconv.ParseFloat(strings.TrimSpace(f[1]), 64)
		if err1 != nil || err2 != nil {
			continue
		}
		uninherited := bl > 0
		if len(f) >= 7 {
			uninherited = strings.TrimSpace(f[6]) == "1"
		}
		if uninherited && bl > 0 {
			q.TimingPoints = append(q.TimingPoints, quaTiming{StartTime: t, Bpm: 60000 / bl})
		}
	}
	k := int(keys)
	for _, f := range hits {
		if len(f) < 5 || k <= 0 {
			continue
		}
		x, _ := strconv.ParseFloat(f[0], 64)
		t, err := strconv.ParseFloat(f[2], 64)
		if err != nil {
			continue
		}
		typ, _ := strconv.Atoi(f[3])
		lane := int(math.Floor(x * float64(k) / 512))
		lane = max(0, min(k-1, lane))
		h := quaHit{StartTime: t, Lane: lane + 1}
		if typ&128 != 0 && len(f) >= 6 {
			end, _, _ := strings.Cut(f[5], ":")
			if e, err := strconv.ParseFloat(end, 64); err == nil {
				h.EndTime = e
			}
		}
		q.HitObjects = append(q.HitObjects, h)
	}
	return q, nil
}

func scanOsuSet(setDir string, logf func(string, ...any)) []*quaverSong {
	return scanSet(setDir, ".osu", parseOsu, logf)
}

func firstNonEmpty(a ...string) string {
	for _, s := range a {
		if strings.TrimSpace(s) != "" {
			return s
		}
	}
	return ""
}

func baseName(p string) string {
	if i := strings.LastIndexAny(p, `/\`); i >= 0 {
		return p[i+1:]
	}
	return p
}

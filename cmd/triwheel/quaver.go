package main

// Reads Quaver map sets (.qua, YAML) from the player's own Quaver folder and
// writes one Etterna .sm per song. Audio and art stay in Quaver's folder; the
// .sm reaches them through a junction named "src".

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

type quaTiming struct {
	StartTime float64 `yaml:"StartTime"`
	Bpm       float64 `yaml:"Bpm"`
}

type quaHit struct {
	StartTime float64 `yaml:"StartTime"`
	Lane      int     `yaml:"Lane"`
	EndTime   float64 `yaml:"EndTime"`
}

type quaMap struct {
	AudioFile       string      `yaml:"AudioFile"`
	SongPreviewTime float64     `yaml:"SongPreviewTime"`
	BackgroundFile  string      `yaml:"BackgroundFile"`
	BannerFile      string      `yaml:"BannerFile"`
	Mode            string      `yaml:"Mode"`
	HasScratchKey   bool        `yaml:"HasScratchKey"`
	Title           string      `yaml:"Title"`
	Artist          string      `yaml:"Artist"`
	Creator         string      `yaml:"Creator"`
	DifficultyName  string      `yaml:"DifficultyName"`
	TimingPoints    []quaTiming `yaml:"TimingPoints"`
	HitObjects      []quaHit    `yaml:"HitObjects"`

	TitleTranslit, ArtistTranslit string // romanized names (osu! keeps both)

	file   string // base name of the chart file
	source string // games sheet id: "quaver" or "osu"
}

func parseQua(path string) (*quaMap, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	b = []byte(strings.TrimPrefix(string(b), "\ufeff"))
	var q quaMap
	if err := yaml.Unmarshal(b, &q); err != nil {
		return nil, err
	}
	q.file = filepath.Base(path)
	q.source = "quaver"
	return &q, nil
}

// modeFor looks the chart up in the modes sheet.
func modeFor(q *quaMap) ModeRow {
	key := q.Mode
	if q.Mode == "Keys7" && q.HasScratchKey {
		key = "Keys7+HasScratchKey"
	}
	src := q.source
	if src == "" {
		src = "quaver"
	}
	for _, m := range Modes {
		if m.Source == src && m.SourceMode == key {
			return m
		}
	}
	return ModeRow{ID: src + "-unknown", Action: "skip", SourceMode: q.Mode}
}

// timing is the song-level tempo map, in ms, with beat 0 at originMs.
type timing struct {
	originMs float64
	points   []quaTiming // sorted, bpm > 0
	beats    []float64   // beat at each point
}

func timingKey(tps []quaTiming) string {
	var sb strings.Builder
	for _, t := range cleanTiming(tps) {
		fmt.Fprintf(&sb, "%.0f=%.4f;", t.StartTime, t.Bpm)
	}
	return sb.String()
}

func cleanTiming(tps []quaTiming) []quaTiming {
	var out []quaTiming
	for _, t := range tps {
		if t.Bpm >= 0.01 && !math.IsInf(t.Bpm, 0) && !math.IsNaN(t.Bpm) {
			out = append(out, t)
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].StartTime < out[j].StartTime })
	// same start time: the later one in the file wins
	var dedup []quaTiming
	for _, t := range out {
		if len(dedup) > 0 && dedup[len(dedup)-1].StartTime == t.StartTime {
			dedup[len(dedup)-1] = t
			continue
		}
		dedup = append(dedup, t)
	}
	return dedup
}

func newTiming(tps []quaTiming, earliestMs float64) (*timing, error) {
	pts := cleanTiming(tps)
	if len(pts) == 0 {
		return nil, fmt.Errorf("no usable timing points")
	}
	beatLen := 60000 / pts[0].Bpm
	origin := pts[0].StartTime
	if earliestMs < origin {
		k := math.Ceil((origin - earliestMs) / beatLen)
		origin -= k * beatLen
	}
	t := &timing{originMs: origin}
	// beat 0 starts at origin with the first bpm
	if origin < pts[0].StartTime {
		pts = append([]quaTiming{{StartTime: origin, Bpm: pts[0].Bpm}}, pts...)
	}
	beat := 0.0
	for i, p := range pts {
		if i > 0 {
			beat += (p.StartTime - pts[i-1].StartTime) * pts[i-1].Bpm / 60000
		}
		t.points = append(t.points, p)
		t.beats = append(t.beats, beat)
	}
	return t, nil
}

// msAt is the inverse of beatAt.
func (t *timing) msAt(beat float64) float64 {
	i := sort.Search(len(t.beats), func(i int) bool { return t.beats[i] > beat }) - 1
	if i < 0 {
		i = 0
	}
	return t.points[i].StartTime + (beat-t.beats[i])*60000/t.points[i].Bpm
}

// fitsTiming reports whether every note of q lands within a couple of milliseconds of where it
// should when written on t's beat grid, so q can share a song (and its tempo map) with t's maps.
func fitsTiming(q *quaMap, t *timing) bool {
	ok := func(ms float64) bool {
		row := math.Round(t.beatAt(ms) * rowsPerBeat)
		return math.Abs(t.msAt(row/rowsPerBeat)-ms) <= 2.5
	}
	for _, h := range q.HitObjects {
		if !ok(h.StartTime) || (h.EndTime > h.StartTime && !ok(h.EndTime)) {
			return false
		}
	}
	return true
}

func (t *timing) beatAt(ms float64) float64 {
	i := sort.Search(len(t.points), func(i int) bool { return t.points[i].StartTime > ms }) - 1
	if i < 0 {
		i = 0
	}
	p := t.points[i]
	return t.beats[i] + (ms-p.StartTime)*p.Bpm/60000
}

const rowsPerBeat = 48
const rowsPerMeasure = rowsPerBeat * 4

type smChart struct {
	q     *quaMap
	mode  ModeRow
	rows  map[int][]byte // row -> lane chars
	kept  []quaHit       // the notes written (lane by lane, in time order): the ones a replay is judged on
	notes int
	nps   float64
	slot  string
	meter int
}

func buildChart(q *quaMap, mode ModeRow, t *timing) *smChart {
	c := &smChart{q: q, mode: mode, rows: map[int][]byte{}}
	set := func(row, lane int, ch byte) {
		r, ok := c.rows[row]
		if !ok {
			r = []byte(strings.Repeat("0", mode.Lanes))
			c.rows[row] = r
		}
		r[lane] = ch
	}
	byLane := map[int][]quaHit{}
	for _, h := range q.HitObjects {
		if h.Lane < 1 || h.Lane > mode.Lanes {
			continue
		}
		byLane[h.Lane-1] = append(byLane[h.Lane-1], h)
	}
	first, last := math.Inf(1), math.Inf(-1)
	for lane, hs := range byLane {
		sort.SliceStable(hs, func(i, j int) bool { return hs[i].StartTime < hs[j].StartTime })
		busyUntil := -1
		for _, h := range hs {
			row := int(math.Round(t.beatAt(h.StartTime) * rowsPerBeat))
			if row <= busyUntil {
				continue // overlaps a hold or a note already in this lane
			}
			first = math.Min(first, h.StartTime)
			last = math.Max(last, math.Max(h.StartTime, h.EndTime))
			end := -1
			if h.EndTime > h.StartTime {
				end = int(math.Round(t.beatAt(h.EndTime) * rowsPerBeat))
			}
			if end > row {
				set(row, lane, '2')
				set(end, lane, '3')
				busyUntil = end
			} else {
				set(row, lane, '1')
				busyUntil = row
				h.EndTime = 0
			}
			c.kept = append(c.kept, h)
			c.notes++
		}
	}
	if dur := (last - first) / 1000; dur > 1 {
		c.nps = float64(c.notes) / dur
	}
	return c
}

const maxMeasures = 20000 // about 2.5 hours at 120 BPM; gimmick tempos beyond this are skipped

func (c *smChart) maxRow() int {
	m := 0
	for r := range c.rows {
		if r > m {
			m = r
		}
	}
	return m
}

func (c *smChart) noteData() string {
	if len(c.rows) == 0 {
		return strings.Repeat("0", c.mode.Lanes) + "\n"
	}
	// bucket rows by measure once (linear in the number of notes)
	byMeasure := map[int][]int{}
	for r := range c.rows {
		byMeasure[r/rowsPerMeasure] = append(byMeasure[r/rowsPerMeasure], r)
	}
	empty := strings.Repeat("0", c.mode.Lanes)
	var sb strings.Builder
	measures := c.maxRow()/rowsPerMeasure + 1
	for m := 0; m < measures; m++ {
		base := m * rowsPerMeasure
		res := 4
		for _, cand := range []int{4, 8, 12, 16, 24, 32, 48, 64, 96, 192} {
			step := rowsPerMeasure / cand
			ok := true
			for _, r := range byMeasure[m] {
				if (r-base)%step != 0 {
					ok = false
					break
				}
			}
			if ok {
				res = cand
				break
			}
		}
		step := rowsPerMeasure / res
		for i := 0; i < res; i++ {
			if r, ok := c.rows[base+i*step]; ok {
				sb.Write(r)
			} else {
				sb.WriteString(empty)
			}
			sb.WriteByte('\n')
		}
		if m < measures-1 {
			sb.WriteString(",\n")
		}
	}
	return sb.String()
}

var slots = []string{"Beginner", "Easy", "Medium", "Hard", "Challenge"}

// assignSlots gives each chart of one steps type a difficulty slot by density:
// the hardest gets Challenge, then Hard, ...; past five the easiest become Edit.
func assignSlots(cs []*smChart) {
	sort.SliceStable(cs, func(i, j int) bool { return cs[i].nps < cs[j].nps })
	n := len(cs)
	for i, c := range cs {
		fromTop := n - 1 - i
		if fromTop < len(slots) {
			c.slot = slots[len(slots)-1-fromTop]
		} else {
			c.slot = "Edit"
		}
		c.meter = int(math.Max(1, math.Round(c.nps)))
	}
}

func smEscape(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `:`, `\:`, `;`, `\;`, `#`, `\#`, "\r", " ", "\n", " ")
	return r.Replace(strings.TrimSpace(s))
}

type quaverSong struct {
	setDir string // absolute path of the Quaver map set
	name   string // folder name in the library
	title  string // shown title
	maps   []*quaMap
}

// writeSM renders the .sm for one song. srcPrefix is how files in the set folder are reached.
func (s *quaverSong) writeSM(srcPrefix string) (string, []string, error) {
	var notes []string
	earliest := math.Inf(1)
	for _, q := range s.maps {
		for _, h := range q.HitObjects {
			earliest = math.Min(earliest, h.StartTime)
		}
	}
	t, err := newTiming(s.maps[0].TimingPoints, earliest)
	if err != nil {
		return "", nil, err
	}
	var skipped []string
	byType := map[string][]*smChart{}
	var order []string
	for _, q := range s.maps {
		m := modeFor(q)
		if m.Action != "convert" {
			skipped = append(skipped, fmt.Sprintf("%s (%s: %s)", q.file, q.DifficultyName, m.SourceMode))
			continue
		}
		c := buildChart(q, m, t)
		if c.notes == 0 {
			skipped = append(skipped, fmt.Sprintf("%s (%s: no notes)", q.file, q.DifficultyName))
			continue
		}
		if c.maxRow()/rowsPerMeasure > maxMeasures {
			skipped = append(skipped, fmt.Sprintf("%s (%s: tempo gimmicks too extreme for Etterna)", q.file, q.DifficultyName))
			continue
		}
		if _, ok := byType[m.StepsType]; !ok {
			order = append(order, m.StepsType)
		}
		byType[m.StepsType] = append(byType[m.StepsType], c)
	}
	if len(order) == 0 {
		return "", skipped, fmt.Errorf("no charts Etterna can play")
	}
	first := s.maps[0]
	bg := mostCommon(s.maps, func(q *quaMap) string { return q.BackgroundFile })
	banner := mostCommon(s.maps, func(q *quaMap) string { return q.BannerFile })
	if banner == "" {
		banner = bg
	}
	ref := func(f string) string {
		if f == "" {
			return ""
		}
		return smEscape(srcPrefix + f)
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "// Generated by VSRG Hub from your %s set %q. Rebuilt when it changes.\n", gameName(first.source), filepath.Base(s.setDir))
	fmt.Fprintf(&sb, "#TITLE:%s;\n#SUBTITLE:[%s];\n#ARTIST:%s;\n#CREDIT:%s;\n", smEscape(s.title), smEscape(gameName(first.source)), smEscape(first.Artist), smEscape(first.Creator))
	if first.TitleTranslit != "" && first.TitleTranslit != first.Title && s.title == first.Title {
		fmt.Fprintf(&sb, "#TITLETRANSLIT:%s;\n", smEscape(first.TitleTranslit))
	}
	if first.ArtistTranslit != "" && first.ArtistTranslit != first.Artist {
		fmt.Fprintf(&sb, "#ARTISTTRANSLIT:%s;\n", smEscape(first.ArtistTranslit))
	}
	fmt.Fprintf(&sb, "#BANNER:%s;\n#BACKGROUND:%s;\n#MUSIC:%s;\n", ref(banner), ref(bg), ref(first.AudioFile))
	fmt.Fprintf(&sb, "#OFFSET:%.6f;\n", -t.originMs/1000)
	if first.SongPreviewTime > 0 {
		fmt.Fprintf(&sb, "#SAMPLESTART:%.3f;\n#SAMPLELENGTH:15.000;\n", first.SongPreviewTime/1000)
	}
	sb.WriteString("#BPMS:")
	for i, p := range t.points {
		if i > 0 {
			sb.WriteString(",\n")
		}
		fmt.Fprintf(&sb, "%.6f=%.6f", t.beats[i], p.Bpm)
	}
	sb.WriteString(";\n#STOPS:;\n")
	for _, st := range order {
		cs := byType[st]
		assignSlots(cs)
		for _, c := range cs {
			fmt.Fprintf(&sb, "\n//---------------%s - %s----------------\n", st, smEscape(c.q.DifficultyName))
			fmt.Fprintf(&sb, "#NOTES:\n     %s:\n     %s:\n     %s:\n     %d:\n     0,0,0,0,0:\n", st, smEscape(c.q.DifficultyName), c.slot, c.meter)
			notes = append(notes, c.noteData())
			sb.WriteString(notes[len(notes)-1])
			sb.WriteString(";\n")
		}
	}
	return sb.String(), skipped, nil
}

func mostCommon(ms []*quaMap, f func(*quaMap) string) string {
	count := map[string]int{}
	best, bestN := "", 0
	for _, q := range ms {
		v := f(q)
		if v == "" {
			continue
		}
		count[v]++
		if count[v] > bestN {
			best, bestN = v, count[v]
		}
	}
	return best
}

// scanQuaverSet splits one map set into songs: maps sharing audio and tempo map.
func scanQuaverSet(setDir string, logf func(string, ...any)) []*quaverSong {
	return scanSet(setDir, ".qua", parseQua, logf)
}

// scanSet splits one map set into songs: maps sharing audio and tempo map.
func scanSet(setDir, ext string, parse func(string) (*quaMap, error), logf func(string, ...any)) []*quaverSong {
	entries, err := os.ReadDir(setDir)
	if err != nil {
		logf("quaver: cannot read %s: %v", setDir, err)
		return nil
	}
	groups := map[string]*quaverSong{}
	var keys []string
	for _, e := range entries {
		if e.IsDir() || !strings.EqualFold(filepath.Ext(e.Name()), ext) {
			continue
		}
		q, err := parse(filepath.Join(setDir, e.Name()))
		if q == nil && err == nil {
			continue // not a chart this mashup plays (e.g. an osu!standard map)
		}
		if err != nil {
			logf("skip %s/%s: %v", filepath.Base(setDir), e.Name(), err)
			continue
		}
		if q.AudioFile == "" {
			logf("skip %s/%s: no audio file", filepath.Base(setDir), e.Name())
			continue
		}
		if _, err := os.Stat(filepath.Join(setDir, q.AudioFile)); err != nil {
			logf("skip %s/%s: its audio %q is not in the set", filepath.Base(setDir), e.Name(), q.AudioFile)
			continue
		}
		// difficulties of one song share its audio; they stay one song (one entry with its charts to
		// pick from) unless their tempo maps really disagree, which .sm can't hold in one file
		audio := strings.ToLower(q.AudioFile)
		k := audio + "|" + timingKey(q.TimingPoints)
		g, ok := groups[k]
		if !ok {
			for _, ok2 := range keys {
				g2 := groups[ok2]
				if !strings.HasPrefix(ok2, audio+"|") {
					continue
				}
				earliest := math.Inf(1)
				for _, m := range append([]*quaMap{q}, g2.maps...) {
					for _, h := range m.HitObjects {
						earliest = math.Min(earliest, h.StartTime)
					}
				}
				if t, err := newTiming(g2.maps[0].TimingPoints, earliest); err == nil && fitsTiming(q, t) {
					g, ok = g2, true
					break
				}
			}
		}
		if !ok {
			g = &quaverSong{setDir: setDir}
			groups[k] = g
			keys = append(keys, k)
		}
		g.maps = append(g.maps, q)
	}
	sort.SliceStable(keys, func(i, j int) bool { return len(groups[keys[i]].maps) > len(groups[keys[j]].maps) })
	titles := map[string]int{}
	for _, k := range keys {
		titles[groups[k].maps[0].Title]++
	}
	var out []*quaverSong
	for _, k := range keys {
		g := groups[k]
		sort.SliceStable(g.maps, func(a, b int) bool { return g.maps[a].file < g.maps[b].file })
		g.title = g.maps[0].Title
		g.name = safeName(filepath.Base(setDir))
		if len(keys) > 1 { // several songs in one map set: a pack, or one song at several rates
			if d := strings.TrimSpace(g.maps[0].DifficultyName); titles[g.title] > 1 && len(g.maps) == 1 && d != "" {
				switch {
				case strings.Contains(strings.ToLower(d), strings.ToLower(g.title)):
					g.title = d
				case isVarious(g.maps[0].Artist) && strings.Contains(d, " - "):
					g.title = d // a pack naming each song "Artist - Title" in its difficulty name
				default:
					// rate / speed edits ("0.9x", "1.1x") and dan stages: the set's own title stays
					// first, so searching for the song (or the pack) finds every version
					g.title = g.title + " [" + d + "]"
				}
			}
			g.name = safeName(g.title)
		}
		out = append(out, g)
	}
	return out
}

// isVarious: a pack's artist ("Various Artists", "V.A.", ...), whose difficulties are its songs.
func isVarious(a string) bool {
	a = strings.ToLower(strings.TrimSpace(a))
	return strings.HasPrefix(a, "various") || a == "va" || a == "v.a." || a == "v.a" || strings.Contains(a, "various artist")
}

func safeName(s string) string {
	r := strings.NewReplacer("<", "_", ">", "_", ":", "_", "\"", "_", "/", "_", "\\", "_", "|", "_", "?", "_", "*", "_")
	s = strings.TrimRight(r.Replace(s), ". ")
	if s == "" {
		s = "_"
	}
	return s
}

func gameName(id string) string {
	for _, g := range Games {
		if g.ID == id {
			return g.Name
		}
	}
	return "Quaver"
}

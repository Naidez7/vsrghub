package main

// Your osu! plays as VSRG Hub scores. osu! stable keeps a replay of every play in Data/r (one
// .osr each), and osu!lazer keeps its replays, as .osr files too, among its hashed files
// (%AppData%\osu\files). Each replay says which beatmap it was (the .osu file's MD5) and holds the
// key presses; VSRG Hub finds the map among the ones it converted from the osu! Songs folder,
// judges the presses against the chart's notes as Etterna would (Wife3 on judge 4, the same
// windows), and hands the result to the game (Save/VSRGHub/online/osu/jobs.txt), which rates it
// with Etterna's calculator and writes it to the outbox like any play (28 VSRG Hub online.lua).
// Lazer plays on maps that aren't in the stable Songs folder can't be rated (lazer keeps which file
// is which in a database VSRG Hub can't read), and are counted apart.

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/ulikunitz/xz/lzma"
)

// ---------------------------------------------------------------------------------------------
// the .osr file

type osrFrame struct {
	T    int // ms into the song (audio time)
	Keys int // mania: the columns held, bit per column
}

type osrReplay struct {
	Mode                              int
	Version                           int
	BeatmapMD5                        string
	Player                            string
	ReplayMD5                         string
	N300, N100, N50, Geki, Katu, Miss int
	Score                             int
	MaxCombo                          int
	Perfect                           bool
	Mods                              int
	Time                              time.Time
	Frames                            []osrFrame
	Lazer                             *lazerScore // what lazer adds at the end (nil for stable)
}

type lazerScore struct {
	Mods []struct {
		Acronym  string                     `json:"acronym"`
		Settings map[string]json.RawMessage `json:"settings"`
	} `json:"mods"`
	Statistics map[string]int `json:"statistics"`
	Rank       string         `json:"rank"`
}

// osu! stable's mod bits
const (
	modNoFail      = 1 << 0
	modEasy        = 1 << 1
	modHardRock    = 1 << 4
	modSuddenDeath = 1 << 5
	modDoubleTime  = 1 << 6
	modRelax       = 1 << 7
	modHalfTime    = 1 << 8
	modNightcore   = 1 << 9
	modAutoplay    = 1 << 11
	modPerfect     = 1 << 14
	modKey4        = 1 << 15
	modKey5        = 1 << 16
	modKey6        = 1 << 17
	modKey7        = 1 << 18
	modKey8        = 1 << 19
	modRandom      = 1 << 21
	modCinema      = 1 << 22
	modKey9        = 1 << 24
	modKeyCoop     = 1 << 25
	modKey1        = 1 << 26
	modKey3        = 1 << 27
	modKey2        = 1 << 28
	modScoreV2     = 1 << 29
	modMirror      = 1 << 30
	modKeyAny      = modKey1 | modKey2 | modKey3 | modKey4 | modKey5 | modKey6 | modKey7 | modKey8 | modKey9 | modKeyCoop
)

type osrReader struct {
	r   *bufio.Reader
	err error
}

func (o *osrReader) byte_() byte {
	b, err := o.r.ReadByte()
	if err != nil && o.err == nil {
		o.err = err
	}
	return b
}
func (o *osrReader) u16() int {
	var b [2]byte
	if _, err := io.ReadFull(o.r, b[:]); err != nil && o.err == nil {
		o.err = err
	}
	return int(binary.LittleEndian.Uint16(b[:]))
}
func (o *osrReader) i32() int {
	var b [4]byte
	if _, err := io.ReadFull(o.r, b[:]); err != nil && o.err == nil {
		o.err = err
	}
	return int(int32(binary.LittleEndian.Uint32(b[:])))
}
func (o *osrReader) i64() int64 {
	var b [8]byte
	if _, err := io.ReadFull(o.r, b[:]); err != nil && o.err == nil {
		o.err = err
	}
	return int64(binary.LittleEndian.Uint64(b[:]))
}
func (o *osrReader) str() string {
	if o.byte_() != 0x0b {
		return ""
	}
	n := 0
	for shift := 0; ; shift += 7 {
		b := o.byte_()
		n |= int(b&0x7f) << shift
		if b&0x80 == 0 || shift > 28 || o.err != nil {
			break
		}
	}
	if n < 0 || n > 1<<20 {
		o.err = errors.New("bad string")
		return ""
	}
	b := make([]byte, n)
	if _, err := io.ReadFull(o.r, b); err != nil && o.err == nil {
		o.err = err
	}
	return string(b)
}
func (o *osrReader) bytes_(n int) []byte {
	if n < 0 || n > 64<<20 {
		o.err = errors.New("bad length")
		return nil
	}
	b := make([]byte, n)
	if _, err := io.ReadFull(o.r, b); err != nil && o.err == nil {
		o.err = err
	}
	return b
}

// osrHeaderLooksRight: the first bytes of a .osr (mode 0-3, a date-like version, then a string)
func osrHeaderLooksRight(b []byte) bool {
	if len(b) < 6 || b[0] > 3 {
		return false
	}
	v := int(int32(binary.LittleEndian.Uint32(b[1:5])))
	return (v >= 20070000 && v < 20400000 || v >= 30000000 && v < 40000000) && (b[5] == 0x0b || b[5] == 0)
}

func windowsTicks(t int64) time.Time {
	// (100 ns since 0001-01-01)
	const epoch = 621355968000000000
	return time.Unix(0, (t-epoch)*100).UTC()
}

func lzmaDecode(b []byte, limit int64) ([]byte, error) {
	r, err := lzma.NewReader(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	return io.ReadAll(io.LimitReader(r, limit))
}

// readOSR reads a replay file (frames too).
func readOSR(path string) (*osrReplay, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	o := &osrReader{r: bufio.NewReaderSize(f, 64<<10)}
	rp := &osrReplay{}
	rp.Mode = int(o.byte_())
	rp.Version = o.i32()
	rp.BeatmapMD5 = o.str()
	rp.Player = o.str()
	rp.ReplayMD5 = o.str()
	rp.N300, rp.N100, rp.N50, rp.Geki, rp.Katu, rp.Miss = o.u16(), o.u16(), o.u16(), o.u16(), o.u16(), o.u16()
	rp.Score = o.i32()
	rp.MaxCombo = o.u16()
	rp.Perfect = o.byte_() != 0
	rp.Mods = o.i32()
	o.str() // life bar
	rp.Time = windowsTicks(o.i64())
	n := o.i32()
	if o.err != nil {
		return nil, o.err
	}
	data := o.bytes_(n)
	if o.err != nil {
		return nil, o.err
	}
	if rp.Version >= 20140721 {
		o.i64()
	} else if rp.Version >= 20121008 {
		o.i32()
	}
	if rp.Version >= 30000001 {
		// lazer: the score as lazer knows it (mods with their settings)
		if m := o.i32(); o.err == nil && m > 0 && m < 4<<20 {
			if js, err := lzmaDecode(o.bytes_(m), 8<<20); err == nil {
				var ls lazerScore
				if json.Unmarshal(js, &ls) == nil {
					rp.Lazer = &ls
				}
			}
		}
	}
	if n > 0 {
		txt, err := lzmaDecode(data, 64<<20)
		if err != nil {
			return nil, fmt.Errorf("replay data: %v", err)
		}
		t := 0
		for _, fr := range bytes.Split(txt, []byte(",")) {
			p := bytes.Split(fr, []byte("|"))
			if len(p) < 4 {
				continue
			}
			dt, err := strconv.Atoi(string(p[0]))
			if err != nil {
				continue
			}
			if dt == -12345 {
				continue // (the random seed, at the end)
			}
			x, _ := strconv.ParseFloat(string(p[1]), 64)
			t += dt
			rp.Frames = append(rp.Frames, osrFrame{T: t, Keys: int(x)})
		}
	}
	return rp, nil
}

// ---------------------------------------------------------------------------------------------
// judging a replay against a chart, as Etterna judges a play (judge 4)

// Etterna's judge 4 windows (ms) and Wife3's marks
var j4Windows = []float64{22.5, 45, 90, 135, 180}

func wife3(ms float64) float64 {
	m := math.Abs(ms)
	const ridic, maxBoo, zero, dev = 5.0, 180.0, 65.0, 22.7
	switch {
	case m <= ridic:
		return 2
	case m <= zero:
		return 2 * math.Erf((zero-m)/dev)
	case m <= maxBoo:
		return (m - zero) * -5.5 / (maxBoo - zero)
	}
	return -5.5
}

type judged struct {
	Offsets     []float64 // ms, real time (misses as 1000)
	Counts      [6]int    // marvelous, perfect, great, good, bad, miss
	Taps        int
	HoldsMissed int
	MaxCombo    int
	Wife        float64 // percent
}

// judgeReplay: the presses (per column, audio-time ms) against the chart's kept notes. rate scales
// the song's time (the windows are in real time); mirror flips the columns.
func judgeReplay(notes []quaHit, keys int, frames []osrFrame, rate float64, mirror bool) judged {
	// presses: rising edges per column
	presses := make([][]float64, keys)
	last := 0
	for _, f := range frames {
		for c := 0; c < keys; c++ {
			bit := 1 << c
			if f.Keys&bit != 0 && last&bit == 0 {
				col := c
				if mirror {
					col = keys - 1 - c
				}
				presses[col] = append(presses[col], float64(f.T))
			}
		}
		last = f.Keys
	}
	// releases: for the holds
	type span struct{ down, up float64 }
	holds := make([][]span, keys)
	{
		var open [16]float64
		last := 0
		for _, f := range frames {
			for c := 0; c < keys; c++ {
				bit := 1 << c
				col := c
				if mirror {
					col = keys - 1 - c
				}
				if f.Keys&bit != 0 && last&bit == 0 {
					open[col] = float64(f.T)
				} else if f.Keys&bit == 0 && last&bit != 0 {
					holds[col] = append(holds[col], span{open[col], float64(f.T)})
				}
			}
			last = f.Keys
		}
		if len(frames) > 0 {
			for c := 0; c < keys; c++ {
				if last&(1<<c) != 0 {
					col := c
					if mirror {
						col = keys - 1 - c
					}
					holds[col] = append(holds[col], span{open[col], math.Inf(1)})
				}
			}
		}
	}
	byLane := make([][]quaHit, keys)
	for _, n := range notes {
		if n.Lane >= 1 && n.Lane <= keys {
			byLane[n.Lane-1] = append(byLane[n.Lane-1], n)
		}
	}
	window := 180 * rate // (audio ms)
	var out judged
	combo := 0
	type ev struct {
		t    float64
		miss bool
	}
	var evs []ev
	for c := 0; c < keys; c++ {
		ns := byLane[c]
		sort.SliceStable(ns, func(i, j int) bool { return ns[i].StartTime < ns[j].StartTime })
		ps := presses[c]
		pi := 0
		for _, n := range ns {
			// the first press within the note's window (earlier presses go to nobody: osu! takes a
			// press for the earliest note still open to it)
			hit := math.NaN()
			for pi < len(ps) && ps[pi] < n.StartTime-window {
				pi++
			}
			if pi < len(ps) && ps[pi] <= n.StartTime+window {
				hit = ps[pi]
				pi++
			}
			out.Taps++
			if math.IsNaN(hit) {
				out.Offsets = append(out.Offsets, 1000)
				out.Counts[5]++
				evs = append(evs, ev{n.StartTime, true})
				if n.EndTime > n.StartTime {
					out.HoldsMissed++
				}
				continue
			}
			ms := (hit - n.StartTime) / rate
			out.Offsets = append(out.Offsets, ms)
			a := math.Abs(ms)
			k := 5
			for i, w := range j4Windows {
				if a <= w {
					k = i
					break
				}
			}
			out.Counts[k]++
			evs = append(evs, ev{n.StartTime, k == 5})
			if n.EndTime > n.StartTime {
				// held to the end (letting go earlier than Etterna allows drops it)
				okHold := false
				for _, s := range holds[c] {
					if s.down <= hit+0.5 && s.down >= hit-0.5 || (s.down <= n.StartTime+window && s.up > n.StartTime) {
						if s.up >= n.EndTime-250*rate {
							okHold = true
						}
						break
					}
				}
				if !okHold {
					out.HoldsMissed++
				}
			}
		}
	}
	sort.Slice(evs, func(i, j int) bool { return evs[i].t < evs[j].t })
	for _, e := range evs {
		if e.miss {
			combo = 0
		} else {
			combo++
			if combo > out.MaxCombo {
				out.MaxCombo = combo
			}
		}
	}
	if out.Taps > 0 {
		p := 0.0
		for _, o := range out.Offsets {
			p += wife3(o)
		}
		p += float64(out.HoldsMissed) * -4.5
		out.Wife = p / (float64(out.Taps) * 2) * 100
	}
	return out
}

// ---------------------------------------------------------------------------------------------
// finding the replays, and the charts they were played on

type osuJob struct {
	Key       string // "O" + the replay's hash
	Source    string // "osu" or "lazer"
	Dir       string // the library song folder: "osu!/<name>"
	StepsType string // "dance-single" / "kb7-single"
	Diff      string // the chart's description (osu!'s Version)
	Keys      int
	Rate      float64
	Mods      string
	PlayedAt  time.Time
	J         judged
}

type osuImportReport struct {
	Found      int            `json:"found"`      // replays read
	Jobs       int            `json:"jobs"`       // handed to the game
	Skipped    map[string]int `json:"skipped"`    // why the others weren't
	LazerOnly  int            `json:"lazerOnly"`  // lazer plays on maps not in the stable Songs folder
	DatesFixed int            `json:"datesFixed"` // plays already sent whose date was put right
	Error      string         `json:"error,omitempty"`
}

// rateOf: the song's speed from the mods (0: not a rate Etterna has)
func rateOf(rp *osrReplay) float64 {
	rate := 1.0
	if rp.Lazer != nil {
		for _, m := range rp.Lazer.Mods {
			switch m.Acronym {
			case "DT", "NC":
				rate = 1.5
			case "HT", "DC":
				rate = 0.75
			case "WU", "WD", "AS":
				return 0
			}
			if v, ok := m.Settings["speed_change"]; ok {
				var f float64
				if json.Unmarshal(v, &f) == nil && f > 0 {
					rate = f
				}
			}
		}
	} else {
		if rp.Mods&(modDoubleTime|modNightcore) != 0 {
			rate = 1.5
		} else if rp.Mods&modHalfTime != 0 {
			rate = 0.75
		}
	}
	// (Etterna's rates go by 0.05, from 0.7 to 3.0)
	snapped := math.Round(rate*20) / 20
	if math.Abs(snapped-rate) > 0.001 || snapped < 0.7 || snapped > 3 {
		return 0
	}
	return snapped
}

// modsOf: the mods, in words, and whether the play is one VSRG Hub can rate (its reason when not)
func modsOf(rp *osrReplay) (names string, mirror bool, why string) {
	var out []string
	if rp.Lazer != nil {
		for _, m := range rp.Lazer.Mods {
			out = append(out, m.Acronym)
			switch m.Acronym {
			case "AT", "CN", "RX", "RD", "AS", "WU", "WD", "CS", "IN", "HO", "FI", "DS", "CO":
				// (autoplay, cinema, relax, random, adaptive speed, wind up/down, cover, invert, hold
				// off, fade in, dual stages, constant speed: the chart or its play isn't the same)
				if m.Acronym != "FI" {
					why = "played with " + m.Acronym
				}
			case "MR":
				mirror = true
			}
			if len(m.Acronym) == 2 && m.Acronym[1] == 'K' && m.Acronym[0] >= '1' && m.Acronym[0] <= '9' {
				why = "played with a key mod"
			}
		}
	} else {
		mods := rp.Mods
		if mods&(modAutoplay|modRelax|modCinema) != 0 {
			why = "autoplay or relax"
		}
		if mods&modRandom != 0 {
			why = "played with Random"
		}
		if mods&modKeyAny != 0 {
			why = "played with a key mod"
		}
		mirror = mods&modMirror != 0
		for _, b := range []struct {
			bit  int
			name string
		}{{modNoFail, "NF"}, {modEasy, "EZ"}, {modHardRock, "HR"}, {modSuddenDeath, "SD"}, {modDoubleTime, "DT"},
			{modHalfTime, "HT"}, {modNightcore, "NC"}, {modPerfect, "PF"}, {modMirror, "MR"}, {modScoreV2, "V2"}} {
			if mods&b.bit != 0 {
				out = append(out, b.name)
			}
		}
	}
	return strings.Join(out, " "), mirror, why
}

// lazerReplayFiles: the .osr files among lazer's hashed files
func lazerReplayFiles(lazerDir string) []string {
	var out []string
	root := filepath.Join(lazerDir, "files")
	subs, _ := os.ReadDir(root)
	for _, s := range subs {
		if !s.IsDir() {
			continue
		}
		fs, _ := os.ReadDir(filepath.Join(root, s.Name()))
		for _, f := range fs {
			if f.IsDir() {
				continue
			}
			p := filepath.Join(root, s.Name(), f.Name())
			fh, err := os.Open(p)
			if err != nil {
				continue
			}
			var head [6]byte
			n, _ := io.ReadFull(fh, head[:])
			fh.Close()
			if n == 6 && head[0] == 3 && osrHeaderLooksRight(head[:]) {
				out = append(out, p)
			}
		}
	}
	return out
}

// lazerDir: where osu!lazer keeps its files ("" when it isn't there)
func lazerDir() string {
	d := filepath.Join(os.Getenv("APPDATA"), "osu")
	if dirExists(filepath.Join(d, "files")) {
		return d
	}
	return ""
}

// importOsuReplays reads every mania replay of osu! stable (osuDir) and lazer, judges the ones on
// charts VSRG Hub converted, and writes them for the game. progress gets a word now and then.
func importOsuReplays(lib, osuDir, quaverDir, data string, progress func(string)) osuImportReport {
	rep := osuImportReport{Skipped: map[string]int{}}
	skip := func(why string) { rep.Skipped[why]++ }
	var files []struct {
		path   string
		source string
	}
	if osuDir != "" {
		rs, _ := filepath.Glob(filepath.Join(osuDir, "Data", "r", "*.osr"))
		for _, r := range rs {
			files = append(files, struct{ path, source string }{r, "osu"})
		}
	}
	if ld := lazerDir(); ld != "" {
		for _, r := range lazerReplayFiles(ld) {
			files = append(files, struct{ path, source string }{r, "lazer"})
		}
	}
	var cache cacheFile
	if b, err := os.ReadFile(filepath.Join(lib, "triwheel-cache.json")); err == nil {
		json.Unmarshal(b, &cache)
	}
	var jobs []osuJob
	if quaverDir != "" {
		jobs = append(jobs, quaverJobs(lib, quaverDir, cache, &rep, progress)...)
	}
	if len(files) == 0 && len(jobs) == 0 {
		rep.Error = "no osu! or Quaver replays were found"
		if osuDir == "" && quaverDir == "" {
			rep.Error = "osu! and Quaver aren't set up on the Games page"
		}
		return rep
	}
	progress(fmt.Sprintf("Reading %d osu! replays", len(files)))
	byHash := map[string]osuHashHit{}
	if osuDir != "" {
		byHash = osuMD5Index(lib, osuDir)
	}
	songsDir := ""
	if osuDir != "" {
		songsDir = osuSongDir(osuDir)
	}
	charts := chartIndex(lib, "osu!", songsDir, scanOsuSet, cache)
	seen := map[string]bool{}
	for i, f := range files {
		if i%200 == 0 {
			progress(fmt.Sprintf("Reading replays: %d of %d", i, len(files)))
		}
		rp, err := readOSR(f.path)
		if err != nil {
			skip("couldn't be read")
			continue
		}
		rep.Found++
		if rp.Mode != 3 {
			skip("not osu!mania")
			continue
		}
		key := "O" + rp.ReplayMD5
		if rp.ReplayMD5 == "" || seen[key] {
			skip("the same play twice")
			continue
		}
		seen[key] = true
		hit, ok := byHash[strings.ToLower(rp.BeatmapMD5)]
		if !ok {
			if f.source == "lazer" {
				rep.LazerOnly++
			} else {
				skip("map no longer in the Songs folder")
			}
			continue
		}
		ch, ok := charts.find(hit.Set, hit.File)
		if !ok {
			skip("map VSRG Hub didn't convert")
			continue
		}
		if ch.keys != 4 && ch.keys != 7 {
			skip(fmt.Sprintf("%dK", ch.keys))
			continue
		}
		mods, mirror, why := modsOf(rp)
		if why != "" {
			skip(why)
			continue
		}
		rate := rateOf(rp)
		if rate == 0 {
			skip("a speed Etterna doesn't have")
			continue
		}
		if len(rp.Frames) < 2 {
			skip("no key presses in the replay")
			continue
		}
		// (a play that stopped before the end: failed or quit)
		lastNote := 0.0
		for _, n := range ch.notes {
			lastNote = math.Max(lastNote, math.Max(n.StartTime, n.EndTime))
		}
		if float64(rp.Frames[len(rp.Frames)-1].T) < lastNote-1000 {
			skip("didn't reach the end")
			continue
		}
		j := judgeReplay(ch.notes, ch.keys, rp.Frames, rate, mirror)
		if j.Taps == 0 {
			skip("map VSRG Hub didn't convert")
			continue
		}
		if j.Wife <= 0 {
			skip("accuracy too low to rate")
			continue
		}
		jobs = append(jobs, osuJob{Key: key, Source: f.source, Dir: ch.dir, StepsType: ch.st, Diff: ch.diff, Keys: ch.keys,
			Rate: rate, Mods: mods, PlayedAt: rp.Time, J: j})
	}
	if len(jobs) == 0 {
		rep.Error = "none of the replays could be rated"
		return rep
	}
	if err := writeJobs(data, jobs); err != nil {
		rep.Error = err.Error()
		return rep
	}
	rep.Jobs = len(jobs)
	// (plays already on the server with the wrong date, from before the dates were read right:
	// their real dates, straight to the server)
	if s, err := onlineToken(); err == nil {
		fixed := 0
		for i := 0; i < len(jobs); i += 500 {
			var list []map[string]any
			for _, j := range jobs[i:min(i+500, len(jobs))] {
				list = append(list, map[string]any{"score_key": j.Key, "played_at": j.PlayedAt.UTC().Format(time.RFC3339)})
			}
			var n int
			if err := onlineCall("POST", "/rest/v1/rpc/fix_played_at", map[string]any{"list": list}, s.Access, &n); err == nil {
				fixed += n
			}
		}
		if fixed > 0 {
			logf("osu!/Quaver replays: %d dates put right on the server", fixed)
			rep.DatesFixed = fixed
		}
	}
	logf("osu!/Quaver replays: %d read, %d for the game, %d lazer-only, skipped %v", rep.Found, rep.Jobs, rep.LazerOnly, rep.Skipped)
	return rep
}

// ---------------------------------------------------------------------------------------------
// the converted charts, found again from the game's own files

type convertedChart struct {
	dir   string // the library song folder, "<group>/<name>"
	st    string // steps type
	diff  string // the chart's description
	keys  int
	notes []quaHit
}

type chartIndexT struct {
	group, songsDir string
	scan            func(string, func(string, ...any)) []*quaverSong
	cache           cacheFile
	sets            map[string]map[string]convertedChart
}

func chartIndex(lib, group, songsDir string, scan func(string, func(string, ...any)) []*quaverSong, cache cacheFile) *chartIndexT {
	return &chartIndexT{group: group, songsDir: songsDir, scan: scan, cache: cache, sets: map[string]map[string]convertedChart{}}
}

// find: the chart made from one map file of a set (scanned once per set, as the library was built)
func (ci *chartIndexT) find(set, file string) (convertedChart, bool) {
	byFile, ok := ci.sets[set]
	if !ok {
		byFile = map[string]convertedChart{}
		ci.sets[set] = byFile
		if ce, ok := ci.cache.Sets[ci.group+"|"+set]; ok && ci.songsDir != "" {
			for _, song := range ci.scan(filepath.Join(ci.songsDir, set), func(string, ...any) {}) {
				// the library folder this song went to (its name, or with " [n]" when another had it)
				dir := ""
				for _, name := range ce.Songs {
					if name == song.name || strings.HasPrefix(name, song.name+" [") {
						dir = name
						break
					}
				}
				if dir == "" || len(song.maps) == 0 {
					continue
				}
				earliest := math.Inf(1)
				for _, q := range song.maps {
					for _, h := range q.HitObjects {
						earliest = math.Min(earliest, h.StartTime)
					}
				}
				tm, err := newTiming(song.maps[0].TimingPoints, earliest)
				if err != nil {
					continue
				}
				for _, q := range song.maps {
					m := modeFor(q)
					if m.Action != "convert" {
						continue
					}
					c := buildChart(q, m, tm)
					if c.notes == 0 || c.maxRow()/rowsPerMeasure > maxMeasures {
						continue
					}
					byFile[strings.ToLower(q.file)] = convertedChart{ci.group + "/" + dir, m.StepsType, q.DifficultyName, m.Lanes, c.kept}
				}
			}
		}
	}
	c, ok := byFile[strings.ToLower(file)]
	return c, ok
}

// writeJobs hands the judged plays to the game: one line each (28 VSRG Hub osu plays.lua)
func writeJobs(data string, jobs []osuJob) error {
	dir := filepath.Join(onlineDir(data), "osu")
	os.MkdirAll(dir, 0o755)
	var sb strings.Builder
	for _, j := range jobs {
		offs := make([]string, len(j.J.Offsets))
		for i, o := range j.J.Offsets {
			offs[i] = strconv.FormatFloat(o, 'f', 2, 64)
		}
		c := j.J.Counts
		fmt.Fprintf(&sb, "%s\t%s\t%s\t%s\t%s\t%d\t%s\t%.4f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\n",
			j.Key, j.Source, tsvSafe(j.Dir), j.StepsType, tsvSafe(j.Diff), j.Keys, strconv.FormatFloat(j.Rate, 'f', 2, 64), j.J.Wife,
			c[0], c[1], c[2], c[3], c[4], c[5], j.J.MaxCombo, j.J.Taps, j.J.HoldsMissed,
			j.PlayedAt.Format("2006-01-02T15:04:05Z"), tsvSafe(j.Mods), strings.Join(offs, ","))
	}
	if err := os.WriteFile(filepath.Join(dir, "jobs.txt"), []byte(sb.String()), 0o644); err != nil {
		return err
	}
	os.Remove(filepath.Join(dir, "done.txt"))
	os.Remove(filepath.Join(dir, "progress.txt"))
	return nil
}

func tsvSafe(s string) string {
	return strings.NewReplacer("\t", " ", "\n", " ", "\r", " ").Replace(s)
}

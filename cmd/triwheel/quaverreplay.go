package main

// Your Quaver plays as VSRG Hub scores: Quaver keeps a replay of each play in Data/r
// (<score id>.qr: a header, then the key presses LZMA-packed, as osu!'s), which names its map by
// the .qua file's MD5. The map is found among the ones VSRG Hub converted from the Quaver Songs
// folder and the play is judged like an osu! one (osureplay.go).

import (
	"bufio"
	"bytes"
	"crypto/md5"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type qrReplay struct {
	Version    string
	MapMD5     string
	MD5        string
	Player     string
	Date       string
	TimePlayed int64 // ms since 1970 (what Quaver trusts; Date is its text in the PC's own format)
	Mode       int   // 1: 4K, 2: 7K
	Mods       int64
	Score      int
	Accuracy   float32
	MaxCombo   int
	Counts     [6]int // marv, perf, great, good, okay, miss
	Pauses     int
	Frames     []osrFrame
}

// Quaver's mods (ModIdentifier)
const (
	qmSpeed05X = 1 << 1
	qmAutoplay = int64(1) << 19
	qmNoLN     = int64(1) << 22
	qmRandom   = int64(1) << 23
	qmInverse  = int64(1) << 29
	qmFullLN   = int64(1) << 30
	qmMirror   = int64(1) << 31
	qmCoop     = int64(1) << 32
)

// the speed mods: bit -> rate
var qmSpeeds = map[int]float64{
	1: 0.5, 2: 0.6, 3: 0.7, 4: 0.8, 5: 0.9, 6: 1.1, 7: 1.2, 8: 1.3, 9: 1.4, 10: 1.5, 11: 1.6, 12: 1.7, 13: 1.8, 14: 1.9, 15: 2.0,
	24: 0.55, 25: 0.65, 26: 0.75, 27: 0.85, 28: 0.95, 33: 1.05, 34: 1.15, 35: 1.25, 36: 1.35, 37: 1.45, 38: 1.55, 39: 1.65, 40: 1.75, 41: 1.85, 42: 1.95,
}

// a .NET BinaryReader string: a 7-bit length, then UTF-8
func netString(r *bufio.Reader) (string, error) {
	n, shift := 0, 0
	for {
		b, err := r.ReadByte()
		if err != nil {
			return "", err
		}
		n |= int(b&0x7f) << shift
		if b&0x80 == 0 {
			break
		}
		shift += 7
		if shift > 28 {
			return "", errors.New("bad string")
		}
	}
	if n < 0 || n > 1<<20 {
		return "", errors.New("bad string")
	}
	buf := make([]byte, n)
	if _, err := io.ReadFull(r, buf); err != nil {
		return "", err
	}
	return string(buf), nil
}

func readQR(path string) (*qrReplay, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(b) > 64<<20 {
		return nil, errors.New("too big")
	}
	br := bytes.NewReader(b)
	r := bufio.NewReaderSize(br, 16)
	rp := &qrReplay{}
	var e error
	str := func() string {
		s, err := netString(r)
		if err != nil && e == nil {
			e = err
		}
		return s
	}
	rp.Version = str()
	rp.MapMD5 = str()
	rp.MD5 = str()
	rp.Player = str()
	rp.Date = str()
	if e != nil {
		return nil, e
	}
	// the rest is fixed-size: time played (int64), mode (int32), mods (int32 in the first replays,
	// int64 later), score, accuracy, max combo, the six judgement counts, pauses, then (depending on
	// the version) a word or two more, then the frames LZMA-packed. The layout is told by trying:
	// the one whose frames unpack and whose accuracy makes sense.
	rest := b[len(b)-br.Len()-r.Buffered():]
	if len(rest) < 8+4+4+4+4+4+24+4 {
		return nil, errors.New("too short")
	}
	i64 := func(o int) int64 { return int64(binary.LittleEndian.Uint64(rest[o:])) }
	i32 := func(o int) int { return int(int32(binary.LittleEndian.Uint32(rest[o:]))) }
	f32 := func(o int) float32 { return math.Float32frombits(binary.LittleEndian.Uint32(rest[o:])) }
	rp.TimePlayed = i64(0)
	rp.Mode = i32(8)
	var ferr error = errors.New("no frames")
	for _, modsSize := range []int{8, 4} {
		o := 12
		var mods int64
		if modsSize == 8 {
			mods = i64(o)
		} else {
			mods = int64(i32(o))
		}
		o += modsSize
		if o+4+4+4+24+4 > len(rest) {
			continue
		}
		score, acc, combo := i32(o), f32(o+4), i32(o+8)
		o += 12
		var counts [6]int
		for k := range counts {
			counts[k] = i32(o)
			o += 4
		}
		pauses := i32(o)
		o += 4
		if acc < 0 || acc > 100 || math.IsNaN(float64(acc)) || (acc > 0 && acc < 0.01) || combo < 0 {
			continue
		}
		for _, extra := range []int{0, 4, 8, 12} {
			s := o + extra
			if s+13 > len(rest) {
				break
			}
			txt, err := lzmaDecode(rest[s:], 64<<20)
			if err != nil {
				ferr = err
				continue
			}
			frames, err := qrFrames(txt)
			if err != nil {
				ferr = err
				continue
			}
			rp.Mods, rp.Score, rp.Accuracy, rp.MaxCombo, rp.Counts, rp.Pauses, rp.Frames = mods, score, acc, combo, counts, pauses, frames
			return rp, nil
		}
	}
	return nil, fmt.Errorf("replay data: %v", ferr)
}

// qrFrames: "time|keys,time|keys,..." (times in ms, absolute)
func qrFrames(txt []byte) ([]osrFrame, error) {
	var out []osrFrame
	for _, fr := range bytes.Split(txt, []byte(",")) {
		fr = bytes.TrimSpace(fr)
		if len(fr) == 0 {
			continue
		}
		a, b, ok := bytes.Cut(fr, []byte("|"))
		if !ok {
			return nil, errors.New("not a frame")
		}
		t, err1 := strconv.Atoi(string(a))
		k, err2 := strconv.Atoi(string(b))
		if err1 != nil || err2 != nil {
			return nil, errors.New("not a frame")
		}
		out = append(out, osrFrame{T: t, Keys: k})
	}
	if len(out) == 0 {
		return nil, errors.New("no frames")
	}
	return out, nil
}

// quaMD5Index: the MD5 of every .qua file in the Quaver Songs folder (cached like osu!'s)
func quaMD5Index(lib, quaverDir string) map[string]osuHashHit {
	cachePath := filepath.Join(lib, "triwheel-qua-md5.json")
	old := map[string]md5Entry{}
	if b, err := os.ReadFile(cachePath); err == nil {
		json.Unmarshal(b, &old)
	}
	byHash := map[string]osuHashHit{}
	fresh := map[string]md5Entry{}
	songsDir := quaverSongDir(quaverDir)
	sets, _ := os.ReadDir(songsDir)
	for _, set := range sets {
		if !set.IsDir() {
			continue
		}
		files, _ := os.ReadDir(filepath.Join(songsDir, set.Name()))
		for _, fe := range files {
			if fe.IsDir() || !strings.EqualFold(filepath.Ext(fe.Name()), ".qua") {
				continue
			}
			info, err := fe.Info()
			if err != nil {
				continue
			}
			key := set.Name() + "/" + fe.Name()
			en, ok := old[key]
			if !ok || en.Size != info.Size() || en.ModTime != info.ModTime().UnixNano() {
				b, err := os.ReadFile(filepath.Join(songsDir, set.Name(), fe.Name()))
				if err != nil {
					continue
				}
				sum := md5.Sum(b)
				en = md5Entry{Size: info.Size(), ModTime: info.ModTime().UnixNano(), MD5: hex.EncodeToString(sum[:])}
			}
			fresh[key] = en
			byHash[en.MD5] = osuHashHit{Set: set.Name(), File: fe.Name()}
		}
	}
	if b, err := json.Marshal(fresh); err == nil {
		os.WriteFile(cachePath, b, 0o644)
	}
	return byHash
}

// quaverJobs: the Quaver plays as jobs for the game (what importOsuReplays does for osu!)
func quaverJobs(lib, quaverDir string, cache cacheFile, rep *osuImportReport, fresh func(string) bool, progress func(string)) []osuJob {
	skip := func(why string) { rep.Skipped["Quaver: "+why]++ }
	all, _ := filepath.Glob(filepath.Join(quaverDir, "Data", "r", "*.qr"))
	if more, _ := filepath.Glob(filepath.Join(quaverDir, "Data", "Replays", "*.qr")); len(more) > 0 {
		all = append(all, more...)
	}
	var files []string
	for _, f := range all {
		if fresh(f) {
			files = append(files, f)
		}
	}
	if len(files) == 0 {
		return nil
	}
	progress(fmt.Sprintf("Reading %d Quaver replays", len(files)))
	byHash := quaMD5Index(lib, quaverDir)
	charts := chartIndex(lib, "Quaver", quaverSongDir(quaverDir), scanQuaverSet, cache)
	var jobs []osuJob
	seen := map[string]bool{}
	for i, f := range files {
		if i%20 == 0 {
			progress(fmt.Sprintf("Reading Quaver replays: %d of %d (each is judged against its map)", i, len(files)))
		}
		rp, err := readQR(f)
		if err != nil {
			skip("couldn't be read")
			continue
		}
		rep.Found++
		key := "Q" + rp.MD5
		if rp.MD5 == "" || seen[key] {
			skip("the same play twice")
			continue
		}
		seen[key] = true
		if rp.Mode != 1 && rp.Mode != 2 {
			skip("not 4K or 7K")
			continue
		}
		hit, ok := byHash[strings.ToLower(rp.MapMD5)]
		if !ok {
			skip("map no longer in the Songs folder")
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
		if rp.Mods&(qmAutoplay|qmRandom|qmInverse|qmFullLN|qmNoLN|qmCoop) != 0 {
			skip("played with a mod that changes the map")
			continue
		}
		rate := 1.0
		var names []string
		for bit, r := range qmSpeeds {
			if rp.Mods&(int64(1)<<bit) != 0 {
				rate = r
				names = append(names, strconv.FormatFloat(r, 'f', -1, 64)+"x")
			}
		}
		mirror := rp.Mods&qmMirror != 0
		if mirror {
			names = append(names, "Mirror")
		}
		if rate < 0.7 || rate > 3 {
			skip("a speed Etterna doesn't have")
			continue
		}
		if len(rp.Frames) < 2 {
			skip("no key presses in the replay")
			continue
		}
		lastNote := 0.0
		for _, n := range ch.notes {
			lastNote = math.Max(lastNote, math.Max(n.StartTime, n.EndTime))
		}
		if float64(rp.Frames[len(rp.Frames)-1].T) < lastNote-1000 {
			skip("didn't reach the end")
			continue
		}
		j := judgeReplay(ch.notes, ch.keys, rp.Frames, rate, mirror)
		if j.Taps == 0 || j.Wife <= 0 {
			skip("accuracy too low to rate")
			continue
		}
		played := quaverPlayedAt(rp)
		jobs = append(jobs, osuJob{Key: key, Source: "quaver", Dir: ch.dir, StepsType: ch.st, Diff: ch.diff, Keys: ch.keys,
			Rate: math.Round(rate*20) / 20, Mods: strings.Join(names, " "), PlayedAt: played, J: j})
	}
	return jobs
}

// quaverPlayedAt: when the play was (Quaver's millisecond clock, or its date text in one of the
// formats Windows writes it in; the import's own time only when neither reads)
func quaverPlayedAt(rp *qrReplay) time.Time {
	if rp.TimePlayed > 946684800000 && rp.TimePlayed < 4102444800000 {
		return time.UnixMilli(rp.TimePlayed).UTC()
	}
	for _, f := range []string{"01/02/2006 15:04:05", "1/2/2006 15:04:05", "1/2/2006 3:04:05 PM", "02/01/2006 15:04:05", "2/1/2006 15:04:05",
		"2006-01-02 15:04:05", "2006-01-02T15:04:05", time.RFC3339, "02.01.2006 15:04:05", "2006/01/02 15:04:05"} {
		if t, err := time.ParseInLocation(f, strings.TrimSpace(rp.Date), time.Local); err == nil {
			return t
		}
	}
	return time.Now()
}

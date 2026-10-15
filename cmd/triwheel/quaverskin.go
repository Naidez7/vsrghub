package main

// Quaver skin details VSRG Hub follows so a Quaver skin looks the way it does in Quaver:
// the skin's settings fall back to its DefaultSkin's (Bar, Arrow or Circle, built into Quaver),
// notes can come from a sprite sheet with one picture per beat snap, notes and receptors can be
// turned per column, and the skins Quaver gets from the Steam Workshop are used too.

import (
	"bufio"
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"golang.org/x/image/draw"
)

// quaverSkinScale: Quaver multiplies the sizes in skin.ini by 1920/1366 and lays gameplay out on a
// 1080-tall screen, so a skin size s covers s/768 of the screen's height (480/768 in Etterna pixels).
const quaverSkinScale = 480.0 / 768.0

// quaverDefaults holds what Quaver's built-in skins set for the keys VSRG Hub reads (from Quaver's
// own skin.ini files): a skin that doesn't set one gets its DefaultSkin's.
var quaverDefaults = map[string]map[string]map[string]string{
	"bar": {
		"4k": {"columnsize": "85", "colorobjectsbysnapdistance": "false", "usehitobjectsheet": "false", "rotatehitobjectsbycolumn": "false",
			"flipnoteimagesonupscroll": "true", "flipnoteendimagesonupscroll": "true", "drawlongnoteend": "true", "notepadding": "0", "widthfornoteheightscale": "0", "receptorsoverhitobjects": "true", "hitlightingfps": "60", "holdlightingfps": "60", "hitlightingscale": "100", "holdlightingscale": "100"},
		"7k": {"columnsize": "58", "colorobjectsbysnapdistance": "false", "usehitobjectsheet": "false", "rotatehitobjectsbycolumn": "false",
			"flipnoteimagesonupscroll": "true", "flipnoteendimagesonupscroll": "true", "drawlongnoteend": "true", "notepadding": "0", "widthfornoteheightscale": "0", "receptorsoverhitobjects": "true", "hitlightingfps": "60", "holdlightingfps": "60", "hitlightingscale": "100", "holdlightingscale": "100"},
	},
	"circle": {
		"4k": {"columnsize": "90", "colorobjectsbysnapdistance": "false", "usehitobjectsheet": "false", "rotatehitobjectsbycolumn": "false",
			"flipnoteimagesonupscroll": "true", "flipnoteendimagesonupscroll": "true", "drawlongnoteend": "true", "notepadding": "0", "widthfornoteheightscale": "0", "receptorsoverhitobjects": "false", "hitlightingfps": "60", "holdlightingfps": "60", "hitlightingscale": "100", "holdlightingscale": "100"},
		"7k": {"columnsize": "58", "colorobjectsbysnapdistance": "false", "usehitobjectsheet": "false", "rotatehitobjectsbycolumn": "false",
			"flipnoteimagesonupscroll": "true", "flipnoteendimagesonupscroll": "true", "drawlongnoteend": "true", "notepadding": "0", "widthfornoteheightscale": "0", "receptorsoverhitobjects": "false", "hitlightingfps": "60", "holdlightingfps": "60", "hitlightingscale": "100", "holdlightingscale": "100"},
	},
	"arrow": {
		"4k": {"columnsize": "90", "colorobjectsbysnapdistance": "true", "usehitobjectsheet": "true", "rotatehitobjectsbycolumn": "true",
			"hitobjectrotations":       "90,0,180,270",
			"flipnoteimagesonupscroll": "false", "flipnoteendimagesonupscroll": "true", "drawlongnoteend": "true", "notepadding": "0", "widthfornoteheightscale": "0", "receptorsoverhitobjects": "false", "hitlightingfps": "60", "holdlightingfps": "60", "hitlightingscale": "100", "holdlightingscale": "100"},
		"7k": {"columnsize": "58", "colorobjectsbysnapdistance": "true", "usehitobjectsheet": "true", "rotatehitobjectsbycolumn": "true",
			"hitobjectrotations":       "90,135,180,0,180,225,270",
			"flipnoteimagesonupscroll": "false", "flipnoteendimagesonupscroll": "true", "drawlongnoteend": "true", "notepadding": "0", "widthfornoteheightscale": "0", "receptorsoverhitobjects": "false", "hitlightingfps": "60", "holdlightingfps": "60", "hitlightingscale": "100", "holdlightingscale": "100"},
	},
}

// quaverSnapSuffixes: Quaver's per-snap note files after the 1/1 one (note-hitobject-1-2nd...). Their
// order is Etterna's note colours' too (4th, 8th, 12th, 16th, 24th, 32nd, 48th, 64th, 192nd).
var quaverSnapSuffixes = []string{"2nd", "3rd", "4th", "6th", "8th", "12th", "16th", "48th"}

// quaverConfig reads the player's quaver.cfg (key = value lines).
func quaverConfig(quaverDir string) map[string]string {
	out := map[string]string{}
	f, err := os.Open(filepath.Join(quaverDir, "quaver.cfg"))
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		k, v, ok := strings.Cut(sc.Text(), "=")
		if ok {
			out[strings.ToLower(strings.TrimSpace(k))] = strings.TrimSpace(v)
		}
	}
	return out
}

// quaverSkinDirs lists the player's Quaver skins: the Skins folder and the ones Quaver downloaded
// from the Steam Workshop (one numbered folder each). name is what VSRG Hub calls the skin.
type quaverSkinDir struct{ dir, name string }

func quaverSkinDirs(quaverDir string) []quaverSkinDir {
	var out []quaverSkinDir
	cfg := quaverConfig(quaverDir)
	skins := filepath.Join(quaverDir, "Skins")
	if v := cfg["skindirectory"]; v != "" && dirExists(v) {
		skins = v
	}
	if dirs, err := os.ReadDir(skins); err == nil {
		for _, d := range dirs {
			if d.IsDir() {
				out = append(out, quaverSkinDir{filepath.Join(skins, d.Name()), d.Name()})
			}
		}
	}
	workshop := filepath.Join(quaverDir, "..", "..", "workshop", "content", "980610")
	if v := cfg["steamworkshopdirectory"]; v != "" && dirExists(v) {
		workshop = v
	}
	workshop = filepath.Clean(workshop)
	if dirs, err := os.ReadDir(workshop); err == nil {
		for _, d := range dirs {
			if !d.IsDir() {
				continue
			}
			dir := filepath.Join(workshop, d.Name())
			files := indexSkin(dir)
			if _, ok := files["skin.ini"]; !ok && !dirExists(filepath.Join(dir, "4k")) && !dirExists(filepath.Join(dir, "7k")) {
				continue // not a skin
			}
			name := d.Name()
			for _, s := range readSkinIni(filepath.Join(dir, files.real("skin.ini"))) {
				if s.name == "general" && strings.TrimSpace(s.kv["name"]) != "" {
					name = strings.TrimSpace(s.kv["name"])
				}
			}
			out = append(out, quaverSkinDir{dir, name})
		}
	}
	return out
}

// qvSettings is one key mode's skin.ini section over its DefaultSkin's settings.
type qvSettings struct {
	sec, def map[string]string
}

func (q qvSettings) str(k string) string {
	if v, ok := q.sec[k]; ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return q.def[k]
}

func (q qvSettings) bool(k string) bool { return strings.EqualFold(q.str(k), "true") }

func (q qvSettings) num(k string) float64 {
	f, _ := strconv.ParseFloat(q.str(k), 64)
	return f
}

// ints reads a comma-separated list ("90,0,180,270").
func (q qvSettings) ints(k string) []float64 {
	var out []float64
	for _, p := range strings.Split(q.str(k), ",") {
		if f, err := strconv.ParseFloat(strings.TrimSpace(p), 64); err == nil {
			out = append(out, f)
		}
	}
	return out
}

// qvFrame is one picture: a whole image, or one cell of a sprite sheet (Quaver's
// "name@ROWSxCOLUMNS.png", read row by row).
type qvFrame struct {
	file             string // relative to the skin folder
	rows, cols, cell int
}

var qvSheetName = regexp.MustCompile(`^(.*)@(\d+)x(\d+)\.png$`)

// qvFrames finds an element as Quaver does: a sprite sheet "name@RxC.png" (all its cells) or the
// plain "name.png".
func qvFrames(files skinFiles, rel string) []qvFrame {
	rel = strings.ToLower(rel)
	dir, base := pathDir(rel), pathBase(rel)
	for low, real := range files {
		if pathDir(low) != dir {
			continue
		}
		m := qvSheetName.FindStringSubmatch(pathBase(low))
		if m == nil || m[1] != base {
			continue
		}
		r, _ := strconv.Atoi(m[2])
		c, _ := strconv.Atoi(m[3])
		if r <= 0 || c <= 0 || r*c > 64 {
			continue
		}
		var out []qvFrame
		for i := 0; i < r*c; i++ {
			out = append(out, qvFrame{real, r, c, i})
		}
		return out
	}
	if real, ok := files[rel+".png"]; ok {
		return []qvFrame{{file: real, rows: 1, cols: 1}}
	}
	return nil
}

func pathDir(p string) string {
	if i := strings.LastIndex(p, "/"); i >= 0 {
		return p[:i]
	}
	return ""
}

func pathBase(p string) string { return p[strings.LastIndex(p, "/")+1:] }

// whole reports a frame that is a whole image Etterna can use as it is.
func (f qvFrame) whole() bool { return f.rows*f.cols == 1 }

// noteFrames loads a column's notes the way Quaver does: from the sheet (UseHitObjectSheet) or
// from note-hitobject-N.png and, when the skin colours notes by snap, note-hitobject-N-2nd.png...
func qvNoteFrames(files skinFiles, q qvSettings, mode string, lane int, element, sheetName string) []qvFrame {
	snaps := q.bool("colorobjectsbysnapdistance")
	if q.bool("usehitobjectsheet") {
		name := sheetName
		if q.bool("useperlanespritesheets") {
			name = fmt.Sprintf("%s-%d", sheetName, lane)
		}
		fr := qvFrames(files, mode+"/HitObjects/"+name)
		if !snaps && len(fr) > 1 {
			fr = fr[:1]
		}
		return fr
	}
	one := qvFrames(files, fmt.Sprintf("%s/HitObjects/%s-%d", mode, element, lane))
	if len(one) == 0 {
		return nil
	}
	out := one[:1]
	if snaps {
		for _, s := range quaverSnapSuffixes {
			f := qvFrames(files, fmt.Sprintf("%s/HitObjects/%s-%d-%s", mode, element, lane, s))
			if len(f) == 0 {
				break
			}
			out = append(out, f[0])
		}
	}
	return out
}

// loadFrame decodes one picture.
func loadFrame(skinDir string, f qvFrame) (image.Image, error) {
	fh, err := os.Open(filepath.Join(skinDir, f.file))
	if err != nil {
		return nil, err
	}
	img, _, err := image.Decode(fh)
	fh.Close()
	if err != nil {
		return nil, err
	}
	if f.whole() {
		return img, nil
	}
	b := img.Bounds()
	cw, ch := b.Dx()/f.cols, b.Dy()/f.rows
	if cw <= 0 || ch <= 0 {
		return nil, fmt.Errorf("sheet too small")
	}
	r, c := f.cell/f.cols, f.cell%f.cols
	x0, y0 := b.Min.X+c*cw, b.Min.Y+r*ch
	if s, ok := img.(interface {
		SubImage(image.Rectangle) image.Image
	}); ok {
		return s.SubImage(image.Rect(x0, y0, x0+cw, y0+ch)), nil
	}
	out := image.NewNRGBA(image.Rect(0, 0, cw, ch))
	draw.Copy(out, image.Point{}, img, image.Rect(x0, y0, x0+cw, y0+ch), draw.Src, nil)
	return out, nil
}

func nextPow2(n int) int {
	p := 1
	for p < n {
		p *= 2
	}
	return p
}

// writeSnapSheet writes the pictures one under the other into a power-of-two image (Etterna's note
// colours move the picture down by a fixed share of the texture per snap, so no padding is allowed)
// and returns the number of slots and the pictures' height over width.
func writeSnapSheet(skinDir string, frames []qvFrame, dst string) (slots int, ratio float64, err error) {
	if len(frames) == 0 {
		return 0, 0, fmt.Errorf("no pictures")
	}
	// already written from these very files: only their size is read again (decoding every skin's
	// sheets at each launch takes a while)
	if di, err := os.Stat(dst); err == nil && di.Size() > 0 {
		fresh := true
		for _, f := range frames {
			if si, err := os.Stat(filepath.Join(skinDir, f.file)); err != nil || si.ModTime().After(di.ModTime()) {
				fresh = false
				break
			}
		}
		if fresh {
			if r := frameRatio(skinDir, frames[0]); r > 0 {
				return nextPow2(len(frames)), r, nil
			}
		}
	}
	var imgs []image.Image
	for _, f := range frames {
		img, err := loadFrame(skinDir, f)
		if err != nil {
			return 0, 0, err
		}
		imgs = append(imgs, img)
	}
	if len(imgs) == 0 {
		return 0, 0, fmt.Errorf("no pictures")
	}
	b := imgs[0].Bounds()
	ratio = float64(b.Dy()) / float64(b.Dx())
	slots = nextPow2(len(imgs))
	fw := min(nextPow2(b.Dx()), 256)
	fh := min(nextPow2(b.Dy()), 256)
	for fh*slots > 4096 && fh > 16 {
		fh /= 2
	}
	out := image.NewNRGBA(image.Rect(0, 0, fw, fh*slots))
	for i := 0; i < slots; i++ {
		img := imgs[min(i, len(imgs)-1)]
		draw.CatmullRom.Scale(out, image.Rect(0, i*fh, fw, (i+1)*fh), img, img.Bounds(), draw.Src, nil)
	}
	return slots, ratio, writePNGIfChanged(dst, out)
}

// frameRatio is a picture's height over its width, read from its file's header.
func frameRatio(skinDir string, f qvFrame) float64 {
	fh, err := os.Open(filepath.Join(skinDir, f.file))
	if err != nil {
		return 0
	}
	defer fh.Close()
	cfg, _, err := image.DecodeConfig(fh)
	if err != nil || cfg.Width < f.cols || cfg.Height < f.rows {
		return 0
	}
	return float64(cfg.Height/f.rows) / float64(cfg.Width/f.cols)
}

// writeFramePNG writes one picture (a sheet's first cell) as its own image.
func writeFramePNG(skinDir string, f qvFrame, dst string) error {
	if si, err := os.Stat(filepath.Join(skinDir, f.file)); err == nil {
		if di, err := os.Stat(dst); err == nil && di.Size() > 0 && !si.ModTime().After(di.ModTime()) {
			return nil
		}
	}
	img, err := loadFrame(skinDir, f)
	if err != nil {
		return err
	}
	b := img.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Copy(out, image.Point{}, img, b, draw.Src, nil)
	return writePNGIfChanged(dst, out)
}

// qvRot reads the turn (degrees, clockwise) of column i from a list, 0 when the list is short.
func qvRot(list []float64, i int) float64 {
	if i < len(list) {
		return math.Mod(list[i], 360)
	}
	return 0
}

// writeQuaverEnd writes a Quaver hold end with the hold's body drawn under its lower half (the half
// that lies over the body in Quaver), only when the end or the body changed.
func writeQuaverEnd(endPath, bodyPath, dst string) error {
	if di, err := os.Stat(dst); err == nil && di.Size() > 0 {
		fresh := true
		for _, p := range []string{endPath, bodyPath} {
			if p == "" {
				continue
			}
			if si, err := os.Stat(p); err != nil || si.ModTime().After(di.ModTime()) {
				fresh = false
			}
		}
		if fresh {
			return nil
		}
	}
	end, err := decodeFile(endPath)
	if err != nil {
		return err
	}
	b := end.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h <= 0 {
		return fmt.Errorf("empty image")
	}
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	if bodyPath != "" {
		if body, err := decodeFile(bodyPath); err == nil {
			draw.ApproxBiLinear.Scale(out, image.Rect(0, h/2, w, h), body, body.Bounds(), draw.Src, nil)
		}
	}
	draw.Draw(out, out.Bounds(), end, b.Min, draw.Over)
	return writePNGIfChanged(dst, out)
}

func decodeFile(path string) (image.Image, error) {
	fh, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer fh.Close()
	img, _, err := image.Decode(fh)
	return img, err
}

// qvLight is Quaver's hit or hold lighting: a picture or sprite sheet shown over the receptor when a
// note is hit (played once) or while a hold is held (looped).
type qvLight struct {
	frames     []qvFrame
	File       string  // the sheet as VSRG Hub wrote it, named the way Etterna splits it ("name CxR.png")
	Frames     int     // pictures in it
	FPS, Scale float64 // pictures per second; size in percent of the picture's own
	Rotate     bool    // turned like the column's notes
}

func qvLighting(files skinFiles, q qvSettings, mode, kind string) *qvLight {
	fr := qvFrames(files, mode+"/Lighting/"+kind+"lighting")
	if len(fr) == 0 {
		return nil
	}
	l := &qvLight{frames: fr, Frames: len(fr), FPS: q.num(kind + "lightingfps"), Scale: q.num(kind + "lightingscale"),
		Rotate: q.bool(kind + "lightingcolumnrotation")}
	if l.FPS <= 0 {
		l.FPS = 60
	}
	if l.Scale <= 0 {
		l.Scale = 100
	}
	return l
}

// write copies the lighting picture into the noteskin under a name Etterna splits into its frames.
func (l *qvLight) write(skinDir, dir, rel, kind string, keep map[string]bool) {
	f := l.frames[0]
	name := kind + ".png"
	if !f.whole() {
		name = fmt.Sprintf("%s %dx%d.png", kind, f.cols, f.rows)
	}
	src, dst := filepath.Join(skinDir, f.file), filepath.Join(dir, name)
	si, err := os.Stat(src)
	if err != nil || tooLarge(src) {
		return
	}
	if di, err := os.Stat(dst); err != nil || di.Size() != si.Size() || si.ModTime().After(di.ModTime()) {
		b, err := os.ReadFile(src)
		if err != nil || os.WriteFile(dst, b, 0o644) != nil {
			return
		}
	}
	l.File = "/" + filepath.ToSlash(rel) + "/" + name
	keepAdd(keep, rel+"/"+name)
}

func (l *qvLight) lua() string {
	if l == nil || l.File == "" {
		return "nil"
	}
	return fmt.Sprintf("{ file = %s, n = %d, fps = %s, scale = %s, rotate = %v }", luaStr(l.File), l.Frames, luaNum(l.FPS), luaNum(l.Scale), l.Rotate)
}

// qvHud is the Quaver skin's own gameplay art the Quaver look uses when the notes come from that
// skin: judgements, combo and score digits and the health bar, with the skin's sizes (percent
// values Quaver multiplies by 1920/1366 on a 1080-tall screen).
type qvHud struct {
	Judge                                    map[string]string // Etterna judgement (W1..W5, Miss) -> picture
	Combo, Score                             [10]string
	Decimal, Percent                         string
	HpBg, HpFg                               string
	StageL, StageR                           string // the stage's left and right borders (per key mode)
	JudgeScale, ComboScale                   float64
	ScoreScale, AccScale, RateScale, HpScale float64
	HpVertical                               bool
	frames                                   map[string]qvFrame // sheets: their first picture, written by VSRG Hub
}

func quaverHudFor(files skinFiles, q qvSettings) *qvHud {
	h := &qvHud{Judge: map[string]string{}, frames: map[string]qvFrame{}}
	one := func(rel, key string) string {
		fr := qvFrames(files, rel)
		if len(fr) == 0 {
			return ""
		}
		if fr[0].whole() {
			return fr[0].file
		}
		h.frames[key] = fr[0]
		return "*" + key // written into the noteskin folder
	}
	for et, name := range map[string]string{"W1": "marv", "W2": "perf", "W3": "great", "W4": "good", "W5": "okay", "Miss": "miss"} {
		if f := one("Judgements/judge-"+name, "judge-"+name); f != "" {
			h.Judge[et] = f
		}
	}
	for i := 0; i < 10; i++ {
		h.Combo[i] = one(fmt.Sprintf("Numbers/combo-%d", i), fmt.Sprintf("combo-%d", i))
		h.Score[i] = one(fmt.Sprintf("Numbers/score-%d", i), fmt.Sprintf("score-%d", i))
	}
	h.Decimal = one("Numbers/score-decimal", "score-decimal")
	h.Percent = one("Numbers/score-percent", "score-percent")
	h.HpBg = one("Health/health-background", "health-background")
	h.HpFg = one("Health/health-foreground", "health-foreground")
	num := func(k string, def float64) float64 {
		if _, ok := q.sec[k]; ok {
			return q.num(k)
		}
		return def
	}
	h.JudgeScale = num("judgementhitburstscale", 100)
	h.ComboScale = num("combodisplayscale", 45)
	h.ScoreScale = num("scoredisplayscale", 18)
	h.AccScale = num("accuracydisplayscale", 18)
	h.RateScale = num("ratingdisplayscale", 18)
	h.HpScale = num("healthbarscale", 100)
	h.HpVertical = !strings.EqualFold(strings.TrimSpace(q.sec["healthbartype"]), "horizontal")
	return h
}

// write puts the sheets' first pictures into the noteskin folder and turns every picture into the
// path Etterna loads it by.
func (h *qvHud) write(ns *noteSkin, dir, rel string, keep map[string]bool) {
	src := "/NoteSkins/" + ns.Game + "/" + ns.Name + "/src/"
	fix := func(p string) string {
		if p == "" {
			return ""
		}
		if strings.HasPrefix(p, "*") {
			key := p[1:]
			name := "hud-" + key + ".png"
			if writeFramePNG(ns.Source, h.frames[key], filepath.Join(dir, name)) != nil {
				return ""
			}
			keepAdd(keep, rel+"/"+name)
			return "/" + filepath.ToSlash(rel) + "/" + name
		}
		if tooLarge(filepath.Join(ns.Source, p)) {
			return ""
		}
		return src + p
	}
	for k, v := range h.Judge {
		h.Judge[k] = fix(v)
	}
	for i := range h.Combo {
		h.Combo[i] = fix(h.Combo[i])
		h.Score[i] = fix(h.Score[i])
	}
	h.Decimal, h.Percent = fix(h.Decimal), fix(h.Percent)
	h.HpBg, h.HpFg = fix(h.HpBg), fix(h.HpFg)
	h.StageL, h.StageR = fix(h.StageL), fix(h.StageR)
}

func (h *qvHud) lua() string {
	if h == nil {
		return ""
	}
	var sb strings.Builder
	sb.WriteString("{ judge = {")
	for _, k := range []string{"W1", "W2", "W3", "W4", "W5", "Miss"} {
		if strings.HasPrefix(h.Judge[k], "/") {
			fmt.Fprintf(&sb, " %s = %s,", k, luaStr(h.Judge[k]))
		}
	}
	sb.WriteString(" }")
	digits := func(name string, d [10]string) {
		for _, p := range d {
			if !strings.HasPrefix(p, "/") {
				return // (all ten or none)
			}
		}
		fmt.Fprintf(&sb, ", %s = {", name)
		for i, p := range d {
			fmt.Fprintf(&sb, " [%d] = %s,", i, luaStr(p))
		}
		sb.WriteString(" }")
	}
	digits("combo", h.Combo)
	digits("score", h.Score)
	for k, v := range map[string]string{"decimal": h.Decimal, "percent": h.Percent, "hpBg": h.HpBg, "hpFg": h.HpFg,
		"stageL": h.StageL, "stageR": h.StageR} {
		if strings.HasPrefix(v, "/") {
			fmt.Fprintf(&sb, ", %s = %s", k, luaStr(v))
		}
	}
	fmt.Fprintf(&sb, ", judgeScale = %s, comboScale = %s, scoreScale = %s, accScale = %s, rateScale = %s, hpScale = %s, hpVertical = %v }",
		luaNum(h.JudgeScale), luaNum(h.ComboScale), luaNum(h.ScoreScale), luaNum(h.AccScale), luaNum(h.RateScale), luaNum(h.HpScale), h.HpVertical)
	return sb.String()
}

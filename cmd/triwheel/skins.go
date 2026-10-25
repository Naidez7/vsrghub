package main

// Turns the player's own osu! and Quaver skins into Etterna noteskins (and the
// osu! skin into the look of the VSRG Hub theme). Nothing is copied: each
// generated noteskin is a small Lua file plus a "src" link to the skin folder.

import (
	"bufio"
	"bytes"
	_ "embed"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	_ "golang.org/x/image/bmp"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/tiff"
)

// maniaScale converts osu!mania skin.ini sizes (ColumnWidth, HitPosition...) to Etterna pixels.
// osu!mania lays out on a 480-tall screen like Etterna, so it is 1 (checked side by side with
// osu! stable: a ColumnWidth 78 skin draws 133-pixel columns on an 819-tall window).
const maniaScale = 1.0

//go:embed assets/NoteSkin.lua
var noteSkinTemplate string

//go:embed assets/noteskin-metrics.ini
var noteSkinMetrics string

// skinFiles indexes a skin folder: lower-case relative path (forward slashes) -> real relative path.
type skinFiles map[string]string

func indexSkin(dir string) skinFiles {
	idx := skinFiles{}
	filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if rel, _ := filepath.Rel(dir, p); strings.Count(filepath.ToSlash(rel), "/") >= 3 {
				return filepath.SkipDir
			}
			return nil
		}
		rel, _ := filepath.Rel(dir, p)
		rel = filepath.ToSlash(rel)
		idx[strings.ToLower(rel)] = rel
		return nil
	})
	return idx
}

// tooLarge reports images Etterna cannot load as a texture: huge ones (some skins ship
// 40000-pixel-tall hold bodies that osu! squeezes) and damaged ones. Etterna rejects them, and a
// noteskin with one is silently swapped for another in gameplay.
func tooLarge(path string) bool {
	fh, err := os.Open(path)
	if err != nil {
		return false
	}
	defer fh.Close()
	cfg, format, err := image.DecodeConfig(fh)
	if err != nil || (format != "png" && format != "jpeg") {
		return true // not a PNG/JPEG Etterna can read (osu! is more forgiving: a TIFF named .png works there)
	}
	return cfg.Width > 8192 || cfg.Height > 8192
}

// image finds an element the way osu! does: @2x first, then plain, then the first animation frame.
func (f skinFiles) image(name string) string {
	name = strings.ToLower(strings.ReplaceAll(strings.TrimSpace(name), `\`, "/"))
	name = strings.TrimSuffix(strings.TrimSuffix(name, ".png"), ".jpg")
	for _, cand := range []string{name + "@2x.png", name + ".png", name + "-0@2x.png", name + "-0.png", name + "@2x.jpg", name + ".jpg"} {
		if real, ok := f[cand]; ok {
			return real
		}
	}
	return ""
}

// iniSections parses skin.ini; repeated sections (osu!'s [Mania]) are kept in order.
type iniSection struct {
	name string
	kv   map[string]string
}

func readSkinIni(path string) []iniSection {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	b = bytes.TrimPrefix(b, []byte("\xef\xbb\xbf"))
	var out []iniSection
	cur := iniSection{name: "", kv: map[string]string{}}
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(make([]byte, 64*1024), 4*1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "//") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			out = append(out, cur)
			cur = iniSection{name: strings.ToLower(line[1 : len(line)-1]), kv: map[string]string{}}
			continue
		}
		sep := ":"
		if !strings.Contains(line, ":") {
			sep = "="
		}
		k, v, ok := strings.Cut(line, sep)
		if !ok {
			continue
		}
		if i := strings.Index(v, "//"); i >= 0 {
			v = v[:i]
		}
		cur.kv[strings.ToLower(strings.TrimSpace(k))] = strings.TrimSpace(v)
	}
	return append(out, cur)
}

type nsColumn struct {
	Note, Head, Body, Tail, Key, KeyD string
	// Stretch: the skin stretches the hold body over the whole hold (osu! NoteBodyStyle 0, Quaver)
	// instead of repeating it.
	Stretch bool
	// Repeat: osu!'s repeating body (NoteBodyStyle 1, 2), drawn from the hold's end (see osubody.go)
	Repeat bool
	// Grey: the grey copies of this column's art, by part (greys.go): note, noteS, head, headS,
	// body, tail, tailF, key, keyD, mine
	Grey map[string]string
	// BodyColour: when the skin's hold body can't be used by Etterna (or there is none), VSRG Hub
	// draws the body in this colour, taken from the skin's own art; BodyGen is that generated image.
	BodyColour  *color.NRGBA
	BodyWidth   float64 // share of the column the stand-in body covers
	BodyGen     string
	BodyFit     bool // BodyGen is the skin's own body, shrunk so Etterna can load it
	bodySrc     string
	TailRatio   float64 // the end image's height over its width
	TailFlipped string  // the end image turned upside down (made by VSRG Hub), Etterna path
	// the skin's own proportions (height over width) of a hold body / end that VSRG Hub copied at a
	// power-of-two size (potCopy); 0 when the image is used as it is
	BodyR, TailR float64
	// Quaver: notes and hold heads from a sprite sheet and/or one picture per beat snap; VSRG Hub
	// writes them one under the other (NoteSheet, an Etterna path) and Etterna picks the snap's.
	noteFrames, headFrames []qvFrame
	NoteSheet, HeadSheet   string
	NoteSlots, HeadSlots   int     // pictures the sheet has room for
	NoteCount, HeadCount   int     // pictures in it
	NoteRatio, HeadRatio   float64 // a picture's height over its width
	Mine                   string  // the skin's mine (Etterna path when VSRG Hub wrote it)
	mineFrame              *qvFrame
	bodyFrame              *qvFrame // a hold body that is a sprite sheet: its first picture is used
	NoteRot, KeyRot        float64  // turn of the notes / receptor, degrees clockwise
	HoldStop               float64  // Quaver: where the body stops, from the hold's end (Etterna pixels)
	KeyRatio               float64  // the receptor's height over its width
	// osu!: notes are as tall as they would be in a column WidthForNoteHeightScale wide (the
	// narrowest column when unset), so in a wider column they are flatter than their picture
	NoteHS float64
	Colour [3]int // Quaver's ColumnColorN (the column lighting's tint)
}

// bodyFallback picks a colour for a hold body that is missing or unloadable: the body image's own
// average colour when Go can read it (TIFF, huge PNG), otherwise the head or note art's.
func (c *nsColumn) bodyFallback(dir string) {
	if c.Body != "" || c.bodySrc != "" {
		return // (a body that is only too big is converted when the noteskin is written)
	}
	c.colourFrom(dir, c.Head, c.Note)
}

// colourFrom sets the stand-in body colour from the first of the images Go can read.
func (c *nsColumn) colourFrom(dir string, rels ...string) {
	for _, rel := range rels {
		if rel == "" {
			continue
		}
		src := rel
		if !filepath.IsAbs(src) {
			src = filepath.Join(dir, rel)
		}
		if col, w, ok := averageColour(src); ok {
			c.BodyColour = &col
			c.BodyWidth = w
			return
		}
	}
	c.BodyColour = &color.NRGBA{255, 255, 255, 200}
	c.BodyWidth = 0.9
}

// averageColour is the mean colour of an image's visible pixels (its middle 60% across), with
// their mean opacity, and the share of the image's width they cover.
func averageColour(path string) (color.NRGBA, float64, bool) {
	fh, err := os.Open(path)
	if err != nil {
		return color.NRGBA{}, 0, false
	}
	img, _, err := image.Decode(fh)
	fh.Close()
	if err != nil {
		return color.NRGBA{}, 0, false
	}
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h <= 0 {
		return color.NRGBA{}, 0, false
	}
	stepY := max(1, h/512)
	var r, g, bl, a, n float64
	minX, maxX := w, -1
	for y := b.Min.Y; y < b.Max.Y; y += stepY {
		for x := b.Min.X; x < b.Max.X; x++ {
			c := color.NRGBAModel.Convert(img.At(x, y)).(color.NRGBA)
			if c.A < 32 {
				continue
			}
			if x-b.Min.X < minX {
				minX = x - b.Min.X
			}
			if x-b.Min.X > maxX {
				maxX = x - b.Min.X
			}
			if x-b.Min.X < w/5 || x-b.Min.X >= w-w/5 {
				continue
			}
			r += float64(c.R)
			g += float64(c.G)
			bl += float64(c.B)
			a += float64(c.A)
			n++
		}
	}
	if n == 0 || maxX < minX {
		return color.NRGBA{}, 0, false
	}
	width := float64(maxX-minX+1) / float64(w)
	return color.NRGBA{uint8(r / n), uint8(g / n), uint8(bl / n), uint8(min(255, a/n*0.9))}, width, true
}

// dropUnloadable leaves out images Etterna can't load; a hold body Etterna can't use is converted
// or drawn in its own colour instead (see bodyFallback).
func (c *nsColumn) dropUnloadable(dir string) {
	if c.Body != "" && tooLarge(filepath.Join(dir, c.Body)) {
		c.bodySrc = filepath.Join(dir, c.Body)
	}
	defer c.bodyFallback(dir)
	for _, p := range []*string{&c.Note, &c.Head, &c.Body, &c.Tail, &c.Key, &c.KeyD} {
		if *p != "" && tooLarge(filepath.Join(dir, *p)) {
			if p == &c.Body {
				logf("noteskin: %s can't be loaded by Etterna as it is, converted", filepath.Join(filepath.Base(dir), *p))
			} else {
				logf("noteskin: %s can't be loaded by Etterna, left out", filepath.Join(filepath.Base(dir), *p))
			}
			*p = ""
		}
	}
}

type noteSkin struct {
	Name          string  // folder name in Etterna's noteskin list
	SkinFolder    string  // the osu!/Quaver skin folder name it comes from
	ColWidth      float64 // column width in Etterna pixels (osu! ColumnWidth scaled to a 480-tall screen)
	Game          string  // etterna game: dance or kb7
	Source        string  // skin folder (absolute)
	Cols          []nsColumn
	DownscrollArt bool // art drawn for downscroll (osu!, Quaver): flip for Etterna's upscroll
	ReceptorTop   bool // receptor art hangs below the hit line (osu! key images)
	// the line where notes are hit, drawn across each column: osu!'s mania-stage-hint (bar skins often
	// draw no receptor at all and rely on it) or Quaver's stage-hitposition-overlay
	Hint      string
	HintH     float64 // its height in osu!/Etterna pixels
	JudgeLine bool    // osu!'s JudgementLine: a thin line at the hit position
	// TailFlip: the hold's end image is turned over in downscroll (osu!: its tail art faces the
	// other way to its notes); Quaver's end art is drawn as it is in downscroll and turned in upscroll
	TailFlip bool
	// Quaver: the notes' width when the skin leaves room between columns (NotePadding), how much
	// taller or flatter they are drawn (WidthForNoteHeightScale), and whether notes, receptors and
	// hold ends are turned over in upscroll (FlipNoteImagesOnUpscroll / FlipNoteEndImagesOnUpscroll).
	NoteW   float64
	NoteHS  float64
	Quaver  bool
	RecOver bool // Quaver's ReceptorsOverHitObjects
	// osu!: each column's centre (from the stage's centre) and width, when they aren't all alike
	ColX, ColW []float64
	// osu!: LightingN / LightingL, and how much bigger each column draws them (LightingNWidth /
	// LightingLWidth over 30, or the column's width over 30, in skins of version 2.5 and later)
	LightN, LightL   *osuLight
	LightNS, LightLS []float64
	// Quaver's hit and hold lighting, moved by HitLightingX/Y (Etterna pixels)
	HitLight, HoldLight *qvLight
	LightX, LightY      float64
	// Quaver's column lighting: shown in the column above the receptor while the key is held,
	// ColumnLightingScale tall, ColumnLightingOffsetY above the receptor (Etterna pixels)
	Hud                      *qvHud // Quaver: the skin's judgements, digits and health bar
	ColLight                 string
	// Grey: the grey copies of the skin-wide art (greys.go): hint, lightN, lightL, hitLight,
	// holdLight, colLight
	Grey map[string]string
	ColLightScale, ColLightY float64
	FlipUp                   bool
	EndFlipUp                bool
	HintR                    float64 // the hit line's height over the column's width (Quaver sizes it to the stage)
}

// imageRatio is an image's height over its width (0 when it can't be read).
func imageRatio(dir, rel string) float64 {
	fh, err := os.Open(filepath.Join(dir, rel))
	if err != nil {
		return 0
	}
	defer fh.Close()
	cfg, _, err := image.DecodeConfig(fh)
	if err != nil || cfg.Width == 0 {
		return 0
	}
	return float64(cfg.Height) / float64(cfg.Width)
}

// imageHeight is an image's height in 480-tall screen pixels (an @2x image counts half).
func imageHeight(dir, rel string) float64 {
	fh, err := os.Open(filepath.Join(dir, rel))
	if err != nil {
		return 0
	}
	defer fh.Close()
	cfg, _, err := image.DecodeConfig(fh)
	if err != nil {
		return 0
	}
	h := float64(cfg.Height)
	if strings.Contains(strings.ToLower(rel), "@2x") {
		h /= 2
	}
	return h
}

var osuPatterns = map[int][]string{
	4: {"1", "2", "2", "1"},
	7: {"1", "2", "1", "S", "1", "2", "1"},
}

func osuNoteSkins(skinDir string) []noteSkin {
	files := indexSkin(skinDir)
	ini := readSkinIni(filepath.Join(skinDir, files.real("skin.ini")))
	var out []noteSkin
	for _, keys := range []int{4, 7} {
		// (osu! keeps the first [Mania] section for a key count and ignores repeats)
		var mania map[string]string
		for _, s := range ini {
			if s.name == "mania" && strings.TrimSpace(s.kv["keys"]) == fmt.Sprint(keys) && mania == nil {
				mania = s.kv
			}
		}
		// an image the skin.ini names (NoteImage0T: ...), else osu!'s default name; like osu!, a name
		// that points at no file gives no image (a hold then ends with its head image)
		pick := func(key, def string) string {
			if v := strings.TrimSpace(mania[strings.ToLower(key)]); mania != nil && v != "" {
				if p := files.image(v); p != "" {
					return p
				}
				logf("noteskin: %s: skin.ini %s points to %q, which isn't in the skin", filepath.Base(skinDir), key, v)
				return ""
			}
			return files.image(def)
		}
		ns := noteSkin{Game: map[int]string{4: "dance", 7: "kb7"}[keys], Source: skinDir, DownscrollArt: true, ReceptorTop: true,
			ColWidth: osuColumnWidth(mania), TailFlip: true}
		// columns of different widths, or with gaps between them (ColumnWidth / ColumnSpacing lists)
		widths, gaps := osuColumnLayout(mania, keys)
		uniform := true
		for i := range widths {
			if widths[i] != widths[0] || (i < len(gaps) && gaps[i] != 0) {
				uniform = false
			}
		}
		if !uniform {
			total := 0.0
			for i, w := range widths {
				total += w
				if i < len(gaps) {
					total += gaps[i]
				}
			}
			ns.ColWidth = total / float64(keys) // the stage is as wide as in osu!
			x := -total / 2
			for i, w := range widths {
				ns.ColX = append(ns.ColX, x+w/2)
				x += w
				if i < len(gaps) {
					x += gaps[i]
				}
			}
			ns.ColW = widths
		}
		// note height (osu!: WidthForNoteHeightScale, else the narrowest column's width)
		hsBase := 0.0
		if mania != nil {
			hsBase, _ = strconv.ParseFloat(strings.TrimSpace(mania["widthfornoteheightscale"]), 64)
			hsBase *= maniaScale
		}
		if hsBase <= 0 {
			for i, w := range widths {
				if i == 0 || w < hsBase {
					hsBase = w
				}
			}
		}
		if h := pick("StageHint", "mania-stage-hint"); h != "" && !tooLarge(filepath.Join(skinDir, h)) {
			ns.Hint, ns.HintH = h, imageHeight(skinDir, h)
		}
		ns.JudgeLine = mania != nil && strings.TrimSpace(mania["judgementline"]) == "1"
		lightName := func(key, def string) string {
			if mania != nil && strings.TrimSpace(mania[key]) != "" {
				return strings.TrimSpace(mania[key])
			}
			return def
		}
		ns.LightN = osuLighting(files, skinDir, lightName("lightingn", "lightingN"))
		ns.LightL = osuLighting(files, skinDir, lightName("lightingl", "lightingL"))
		version := 1.0
		for _, s := range ini {
			if s.name == "general" {
				v := strings.TrimSpace(s.kv["version"])
				if strings.EqualFold(v, "latest") {
					version = 99
				} else if f, err := strconv.ParseFloat(v, 64); err == nil {
					version = f
				}
			}
		}
		{
			widths, _ := osuColumnLayout(mania, keys)
			nW, _ := osuColumnLayout(map[string]string{"columnwidth": lightName("lightingnwidth", "")}, keys)
			lW, _ := osuColumnLayout(map[string]string{"columnwidth": lightName("lightinglwidth", "")}, keys)
			set := func(key string) bool { return mania != nil && strings.TrimSpace(mania[key]) != "" }
			for i := 0; i < keys; i++ {
				sn, sl := 1.0, 1.0
				if version >= 2.5 {
					sn, sl = widths[i]/30, widths[i]/30
					if set("lightingnwidth") && nW[i] > 0 {
						sn = nW[i] / 30
					}
					if set("lightinglwidth") && lW[i] > 0 {
						sl = lW[i] / 30
					}
				}
				ns.LightNS = append(ns.LightNS, sn)
				ns.LightLS = append(ns.LightLS, sl)
			}
		}
		ok := true
		for i := 0; i < keys; i++ {
			p := osuPatterns[keys][i]
			c := nsColumn{
				Note: pick(fmt.Sprintf("NoteImage%d", i), "mania-note"+p),
				Head: pick(fmt.Sprintf("NoteImage%dH", i), "mania-note"+p+"H"),
				Body: pick(fmt.Sprintf("NoteImage%dL", i), "mania-note"+p+"L"),
				Tail: pick(fmt.Sprintf("NoteImage%dT", i), "mania-note"+p+"T"),
				Key:  pick(fmt.Sprintf("KeyImage%d", i), "mania-key"+p),
				KeyD: pick(fmt.Sprintf("KeyImage%dD", i), "mania-key"+p+"D"),
			}
			if c.Note == "" { // (osu! would draw nothing; the default note keeps the skin usable)
				c.Note = files.image("mania-note" + p)
			}
			// osu!'s NoteBodyStyle: 0 stretches the body over the hold, 1 (the default) and 2 repeat it
			style := "1"
			if mania != nil {
				if v := strings.TrimSpace(mania["notebodystyle"]); v != "" {
					style = v
				}
				if v := strings.TrimSpace(mania[fmt.Sprintf("notebodystyle%d", i)]); v != "" {
					style = v
				}
			}
			c.Stretch = style == "0"
			c.Repeat = !c.Stretch
			// like osu!, a hold without its own tail image ends with the head image (or the note's)
			if c.Tail == "" {
				c.Tail = firstNonEmpty(c.Head, c.Note)
			}
			c.dropUnloadable(skinDir)
			if c.Tail != "" {
				c.TailRatio = imageRatio(skinDir, c.Tail)
			}
			if c.Note == "" {
				ok = false
				break
			}
			if hsBase > 0 && i < len(widths) && widths[i] > 0 && math.Abs(hsBase/widths[i]-1) > 0.001 {
				c.NoteHS = hsBase / widths[i]
			}
			ns.Cols = append(ns.Cols, c)
		}
		if ok {
			out = append(out, ns)
		}
	}
	return out
}

// quaverNoteSkins makes a 4K and a 7K noteskin from a Quaver skin's 4k/ and 7k/ art, sized and
// drawn the way Quaver draws it (see quaverskin.go). defaultSkin is the player's DefaultSkin in
// quaver.cfg, used when the skin doesn't name one.
func quaverNoteSkins(skinDir, defaultSkin string) []noteSkin {
	files := indexSkin(skinDir)
	ini := readSkinIni(filepath.Join(skinDir, files.real("skin.ini")))
	var out []noteSkin
	for _, mode := range []struct {
		dir, game string
		keys      int
	}{{"4k", "dance", 4}, {"7k", "kb7", 7}} {
		sec := map[string]string{}
		for _, s := range ini {
			if s.name == mode.dir {
				for k, v := range s.kv {
					sec[k] = v
				}
			}
		}
		def := strings.ToLower(strings.TrimSpace(sec["defaultskin"]))
		if quaverDefaults[def] == nil {
			def = strings.ToLower(defaultSkin)
		}
		if quaverDefaults[def] == nil {
			def = "bar"
		}
		q := qvSettings{sec: sec, def: quaverDefaults[def][mode.dir]}
		size := q.num("columnsize")
		if size <= 0 {
			size = 64 / quaverSkinScale
		}
		pad := max(0, q.num("notepadding"))
		ns := noteSkin{Game: mode.game, Source: skinDir, DownscrollArt: true, Quaver: true,
			ColWidth: (size + pad) * quaverSkinScale, NoteW: size * quaverSkinScale, NoteHS: 1,
			FlipUp: q.bool("flipnoteimagesonupscroll"), EndFlipUp: q.bool("flipnoteendimagesonupscroll"),
			RecOver: q.bool("receptorsoverhitobjects")}
		// WidthForNoteHeightScale: notes are as tall as they would be in a column that wide (Quaver
		// reads it as screen pixels, unscaled; its columns are ColumnSize * 1920/1366 wide)
		if w := q.num("widthfornoteheightscale"); w > 0 {
			ns.NoteHS = w / (size * 1920 / 1366)
		}
		if h := files.image(mode.dir + "/Stage/stage-hitposition-overlay"); h != "" && !tooLarge(filepath.Join(skinDir, h)) {
			if r := imageRatio(skinDir, h); r > 0 {
				ns.Hint, ns.HintR = h, r*float64(mode.keys)
			}
		}
		ns.Hud = quaverHudFor(files, q)
		// the stage's borders, left and right of the columns (this key mode's)
		for _, b := range []struct {
			dst  *string
			name string
		}{{&ns.Hud.StageL, "stage-left-border"}, {&ns.Hud.StageR, "stage-right-border"}} {
			if f := files.image(mode.dir + "/Stage/" + b.name); f != "" && !tooLarge(filepath.Join(skinDir, f)) {
				*b.dst = f
			}
		}
		ns.HitLight = qvLighting(files, q, mode.dir, "hit")
		ns.HoldLight = qvLighting(files, q, mode.dir, "hold")
		ns.LightX, ns.LightY = q.num("hitlightingx")*quaverSkinScale, q.num("hitlightingy")*quaverSkinScale
		if cl := files.image(mode.dir + "/Lighting/column-lighting"); cl != "" && !tooLarge(filepath.Join(skinDir, cl)) {
			ns.ColLight = cl
			ns.ColLightScale = q.num("columnlightingscale")
			if _, set := q.sec["columnlightingscale"]; !set {
				ns.ColLightScale = 1
			}
			ns.ColLightY = q.num("columnlightingoffsety") * quaverSkinScale
		}
		drawEnd := q.bool("drawlongnoteend")
		var noteRot, keyRot []float64
		if q.bool("rotatehitobjectsbycolumn") {
			noteRot = q.ints("hitobjectrotations")
		}
		if q.bool("rotatereceptorsbycolumn") {
			keyRot = q.ints("receptorrotations")
		}
		ok := true
		for i := 1; i <= mode.keys; i++ {
			one := func(f string) string {
				if fr := qvFrames(files, fmt.Sprintf("%s/%s-%d", mode.dir, f, i)); len(fr) > 0 && fr[0].whole() {
					return fr[0].file
				}
				return ""
			}
			c := nsColumn{
				Key:     firstNonEmpty(one("Receptors/receptor-up"), files.image(mode.dir+"/Receptors/receptor-up-1")),
				KeyD:    firstNonEmpty(one("Receptors/receptor-down"), files.image(mode.dir+"/Receptors/receptor-down-1")),
				Stretch: true, // Quaver stretches hold bodies
				NoteRot: qvRot(noteRot, i-1),
				KeyRot:  qvRot(keyRot, i-1),
			}
			c.noteFrames = qvNoteFrames(files, q, mode.dir, i, "note-hitobject", "note-hitobject-sheet")
			if len(c.noteFrames) == 0 && !q.bool("usehitobjectsheet") {
				// (Quaver would draw its built-in note here; the first column's is the nearest)
				c.noteFrames = qvNoteFrames(files, q, mode.dir, 1, "note-hitobject", "note-hitobject-sheet")
			}
			c.headFrames = qvNoteFrames(files, q, mode.dir, i, "note-holdhitobject", "note-holdobject-sheet")
			if len(c.headFrames) == 0 {
				c.headFrames = c.noteFrames
			}
			if len(c.noteFrames) == 1 && c.noteFrames[0].whole() {
				c.Note = c.noteFrames[0].file
				c.noteFrames = nil
			} else if len(c.noteFrames) > 0 {
				c.Note = c.noteFrames[0].file // (stands for the sheet VSRG Hub writes)
			}
			if len(c.headFrames) == 1 && c.headFrames[0].whole() {
				c.Head = c.headFrames[0].file
				c.headFrames = nil
			}
			if body := qvFrames(files, fmt.Sprintf("%s/HitObjects/note-holdbody-%d", mode.dir, i)); len(body) > 0 {
				if body[0].whole() {
					c.Body = body[0].file
				} else {
					c.bodyFrame = &body[0]
				}
			}
			if drawEnd {
				c.Tail = one("HitObjects/note-holdend")
			}
			mines := qvFrames(files, fmt.Sprintf("%s/HitObjects/note-mine-%d", mode.dir, i))
			if q.bool("usehitobjectsheet") {
				name := "note-mine-sheet"
				if q.bool("useperlanespritesheets") {
					name = fmt.Sprintf("%s-%d", name, i)
				}
				if m := qvFrames(files, mode.dir+"/HitObjects/"+name); len(m) > 0 {
					mines = m
				}
			}
			if len(mines) > 0 {
				if mines[0].whole() {
					c.Mine = mines[0].file
				} else {
					c.mineFrame = &mines[0]
				}
			}
			c.dropUnloadable(skinDir)
			if c.Tail != "" {
				c.TailRatio = imageRatio(skinDir, c.Tail)
			}
			if c.Key != "" {
				c.KeyRatio = imageRatio(skinDir, c.Key)
			}
			c.Colour = [3]int{255, 255, 255}
			if rgb, ok := parseRGB(q.sec[fmt.Sprintf("columncolor%d", i)]); ok {
				c.Colour = rgb
			}
			if c.Note == "" {
				ok = false
				break
			}
			ns.Cols = append(ns.Cols, c)
		}
		if ok {
			out = append(out, ns)
		} else if _, has := files[mode.dir+"/hitobjects/note-hitobject-1.png"]; has || len(qvFrames(files, mode.dir+"/HitObjects/note-hitobject-sheet")) > 0 {
			logf("noteskin: Quaver skin %s has %s notes VSRG Hub can't use", filepath.Base(skinDir), strings.ToUpper(mode.dir))
		}
	}
	return out
}

func (f skinFiles) real(rel string) string {
	if r, ok := f[strings.ToLower(rel)]; ok {
		return r
	}
	return rel
}

// luaMap writes a string map as a Lua table with its keys in order.
func luaMap(m map[string]string) string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var sb strings.Builder
	sb.WriteString("{")
	for _, k := range keys {
		fmt.Fprintf(&sb, " %s = %s,", k, luaStr(m[k]))
	}
	sb.WriteString(" }")
	return sb.String()
}

func luaStr(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`)
	return `"` + r.Replace(s) + `"`
}

func (ns noteSkin) lua() string {
	var sb strings.Builder
	sb.WriteString("{\n\tdir = " + luaStr("/NoteSkins/"+ns.Game+"/"+ns.Name+"/src/") + ",\n")
	fmt.Fprintf(&sb, "\tdownscrollArt = %v,\n\treceptorTop = %v,\n\twidth = %.2f,\n", ns.DownscrollArt, ns.ReceptorTop, ns.ColWidth)
	if ns.Hint != "" {
		fmt.Fprintf(&sb, "\thint = %s,\n\thintH = %s,\n", luaStr(ns.Hint), luaNum(ns.HintH))
	}
	if ns.HintR > 0 {
		fmt.Fprintf(&sb, "\thintR = %s,\n", luaNum(ns.HintR))
	}
	if ns.LightN != nil || ns.LightL != nil {
		fmt.Fprintf(&sb, "\tlightN = %s,\n\tlightL = %s,\n", ns.LightN.lua(), ns.LightL.lua())
	}
	if ns.Quaver {
		fmt.Fprintf(&sb, "\tquaver = true,\n\tnoteW = %s,\n\tnoteHS = %s,\n\tflipUp = %v,\n\tendFlipUp = %v,\n\trecOver = %v,\n",
			luaNum(math.Round(ns.NoteW*1000)/1000), luaNum(math.Round(ns.NoteHS*10000)/10000), ns.FlipUp, ns.EndFlipUp, ns.RecOver)
		fmt.Fprintf(&sb, "\thitLight = %s,\n\tholdLight = %s,\n\tlightX = %s,\n\tlightY = %s,\n",
			ns.HitLight.lua(), ns.HoldLight.lua(), luaNum(math.Round(ns.LightX*100)/100), luaNum(math.Round(ns.LightY*100)/100))
		if ns.ColLight != "" {
			fmt.Fprintf(&sb, "\tcolLight = %s,\n\tcolLightScale = %s,\n\tcolLightY = %s,\n", luaStr(ns.ColLight), luaNum(ns.ColLightScale), luaNum(math.Round(ns.ColLightY*100)/100))
		}
	}
	if len(ns.Grey) > 0 {
		sb.WriteString("\tgrey = " + luaMap(ns.Grey) + ",\n")
	}
	fmt.Fprintf(&sb, "\tjudgeLine = %v,\n\ttailFlip = %v,\n\tbuttons = {", ns.JudgeLine, ns.TailFlip)
	buttons := map[string][]string{"dance": {"Left", "Down", "Up", "Right"}, "kb7": {"Key1", "Key2", "Key3", "Key4", "Key5", "Key6", "Key7"}}[ns.Game]
	for i, b := range buttons {
		fmt.Fprintf(&sb, " %s = %d,", b, i+1)
	}
	sb.WriteString(" },\n\tcols = {\n")
	opt := func(s string) string {
		if s == "" {
			return "nil"
		}
		return luaStr(s)
	}
	for i, c := range ns.Cols {
		fmt.Fprintf(&sb, "\t\t{ note = %s, head = %s, body = %s, tail = %s, tailF = %s, key = %s, keyD = %s, bodyGen = %s, bodyW = %s, bodyFit = %v",
			luaStr(c.Note), opt(c.Head), opt(c.Body), opt(c.Tail), opt(c.TailFlipped), opt(c.Key), opt(c.KeyD), opt(c.BodyGen), luaNum(c.BodyWidth), c.BodyFit)
		if c.BodyR > 0 {
			fmt.Fprintf(&sb, ", bodyR = %s", luaNum(math.Round(c.BodyR*10000)/10000))
		}
		if c.TailR > 0 {
			fmt.Fprintf(&sb, ", tailR = %s", luaNum(math.Round(c.TailR*10000)/10000))
		}
		if c.NoteSheet != "" {
			fmt.Fprintf(&sb, ", noteS = %s, noteN = %d, noteR = %s", luaStr(c.NoteSheet), c.NoteSlots, luaNum(math.Round(c.NoteRatio*10000)/10000))
		}
		if c.HeadSheet != "" {
			fmt.Fprintf(&sb, ", headS = %s, headN = %d, headR = %s", luaStr(c.HeadSheet), c.HeadSlots, luaNum(math.Round(c.HeadRatio*10000)/10000))
		}
		if c.Mine != "" {
			fmt.Fprintf(&sb, ", mine = %s", luaStr(c.Mine))
		}
		if c.NoteRot != 0 {
			fmt.Fprintf(&sb, ", rot = %s", luaNum(c.NoteRot))
		}
		if c.KeyRot != 0 {
			fmt.Fprintf(&sb, ", keyRot = %s", luaNum(c.KeyRot))
		}
		if i < len(ns.ColW) {
			fmt.Fprintf(&sb, ", w = %s", luaNum(ns.ColW[i]))
		}
		if c.NoteHS > 0 {
			fmt.Fprintf(&sb, ", hs = %s", luaNum(math.Round(c.NoteHS*10000)/10000))
		}
		if i < len(ns.LightNS) {
			fmt.Fprintf(&sb, ", lN = %s, lL = %s", luaNum(math.Round(ns.LightNS[i]*1000)/1000), luaNum(math.Round(ns.LightLS[i]*1000)/1000))
		}
		if ns.Quaver {
			fmt.Fprintf(&sb, ", keyR = %s, colour = { %d, %d, %d }", luaNum(math.Round(c.KeyRatio*10000)/10000), c.Colour[0], c.Colour[1], c.Colour[2])
		}
		if len(c.Grey) > 0 {
			sb.WriteString(", g = " + luaMap(c.Grey))
		}
		sb.WriteString(" },\n")
	}
	sb.WriteString("\t},\n}")
	return sb.String()
}

// osuColumnLayout reads every column's width and the gaps between columns (osu! ColumnWidth and
// ColumnSpacing lists, in osu! pixels on a 480-tall stage; missing entries are 30 wide, 0 apart).
func osuColumnLayout(mania map[string]string, keys int) (widths, gaps []float64) {
	list := func(key string, n int, def float64) []float64 {
		out := make([]float64, n)
		var parts []string
		if mania != nil {
			parts = strings.Split(mania[key], ",")
		}
		for i := range out {
			out[i] = def
			if i < len(parts) {
				if f, err := strconv.ParseFloat(strings.TrimSpace(parts[i]), 64); err == nil && f >= 0 {
					out[i] = f
				}
			}
		}
		return out
	}
	widths = list("columnwidth", keys, 30)
	for i := range widths {
		if widths[i] <= 0 {
			widths[i] = 30
		}
		widths[i] *= maniaScale
	}
	gaps = list("columnspacing", keys-1, 0)
	for i := range gaps {
		gaps[i] *= maniaScale
	}
	return widths, gaps
}

// osuColumnWidth turns a [Mania] section's ColumnWidth (osu! pixels on a 480-tall stage, default 30)
// into Etterna pixels (see maniaScale).
func osuColumnWidth(mania map[string]string) float64 {
	w := 30.0
	if mania != nil {
		if v := strings.TrimSpace(strings.Split(mania["columnwidth"], ",")[0]); v != "" {
			if f, err := strconv.ParseFloat(v, 64); err == nil && f > 0 {
				w = f
			}
		}
	}
	return w * maniaScale
}

// buildNoteSkins writes every usable skin under root/NoteSkins and returns what it made.
func buildNoteSkins(root, osuDir, quaverDir string, keep map[string]bool) (all []noteSkin, osuN, quaverN int) {
	if osuDir != "" {
		dirs, _ := os.ReadDir(filepath.Join(osuDir, "Skins"))
		for _, d := range dirs {
			if !d.IsDir() {
				continue
			}
			for _, ns := range osuNoteSkins(filepath.Join(osuDir, "Skins", d.Name())) {
				ns.Name = osuNoteSkinPrefix + noteSkinSafe(d.Name())
				ns.SkinFolder = d.Name()
				all = append(all, ns)
				osuN++
			}
		}
	}
	if quaverDir != "" {
		def := quaverConfig(quaverDir)["defaultskin"]
		for _, d := range quaverSkinDirs(quaverDir) {
			for _, ns := range quaverNoteSkins(d.dir, def) {
				ns.Name = "quaver_" + noteSkinSafe(d.name)
				// (the interface skins are osu!'s: a Quaver skin never stands for one of them)
				ns.SkinFolder = "quaver:" + d.name
				all = append(all, ns)
				quaverN++
			}
		}
	}
	sort.Slice(all, func(i, j int) bool { return all[i].Game+all[i].Name < all[j].Game+all[j].Name })
	seen := map[string]int{}
	for i := range all {
		k := all[i].Game + "/" + strings.ToLower(all[i].Name)
		seen[k]++
		if seen[k] > 1 {
			all[i].Name = fmt.Sprintf("%s_%d", all[i].Name, seen[k])
		}
	}
	for _, ns := range all {
		rel := filepath.Join("NoteSkins", ns.Game, ns.Name)
		dir := filepath.Join(root, rel)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			logf("noteskin %s: %v", ns.Name, err)
			continue
		}
		if err := ensureJunction(filepath.Join(dir, "src"), ns.Source); err != nil {
			logf("noteskin %s: %v", ns.Name, err)
			continue
		}
		// hold bodies Etterna can't use from the skin: the skin's own body converted, or a plain
		// image in the body's own colour
		if ns.HitLight != nil {
			ns.HitLight.write(ns.Source, dir, rel, "hitlight", keep)
		}
		if ns.Hud != nil {
			ns.Hud.write(&ns, dir, rel, keep)
		}
		if ns.LightN != nil {
			ns.LightN.write(ns.Source, dir, rel, "lightN", keep)
		}
		if ns.LightL != nil {
			ns.LightL.write(ns.Source, dir, rel, "lightL", keep)
		}
		if ns.HoldLight != nil {
			ns.HoldLight.write(ns.Source, dir, rel, "holdlight", keep)
		}
		// Quaver: notes and hold heads with a picture per beat snap (or from a sprite sheet), and
		// a sheet's first picture for mines and hold bodies
		for i := range ns.Cols {
			c := &ns.Cols[i]
			sheet := func(frames []qvFrame, kind string) (string, int, int, float64) {
				if len(frames) == 0 {
					return "", 0, 0, 0
				}
				name := fmt.Sprintf("%s-%d.png", kind, i+1)
				slots, ratio, err := writeSnapSheet(ns.Source, frames, filepath.Join(dir, name))
				if err != nil {
					logf("noteskin %s: %s %d: %v", ns.Name, kind, i+1, err)
					return "", 0, 0, 0
				}
				keepAdd(keep, rel+"/"+name)
				return "/" + filepath.ToSlash(rel) + "/" + name, slots, len(frames), ratio
			}
			c.NoteSheet, c.NoteSlots, c.NoteCount, c.NoteRatio = sheet(c.noteFrames, "notes")
			c.HeadSheet, c.HeadSlots, c.HeadCount, c.HeadRatio = sheet(c.headFrames, "heads")
			one := func(f *qvFrame, kind string) string {
				if f == nil {
					return ""
				}
				name := fmt.Sprintf("%s-%d.png", kind, i+1)
				if err := writeFramePNG(ns.Source, *f, filepath.Join(dir, name)); err != nil {
					logf("noteskin %s: %s %d: %v", ns.Name, kind, i+1, err)
					return ""
				}
				keepAdd(keep, rel+"/"+name)
				return "/" + filepath.ToSlash(rel) + "/" + name
			}
			if m := one(c.mineFrame, "mine"); m != "" {
				c.Mine = m
			}
			if b := one(c.bodyFrame, "body"); b != "" {
				c.BodyGen, c.BodyFit, c.Stretch = b, true, true
				c.BodyColour, c.bodySrc = nil, ""
			}
			if !ns.Quaver {
				continue
			}
			// Quaver draws the hold's body up to the middle of its end image, the end centred on the
			// hold's end, and the body under the end's lower half (most Quaver ends are a cap on top
			// of a see-through half). Etterna starts the end image where the body stops: VSRG Hub
			// stops the body half a note before the end and puts the body under the end's lower half.
			headR := c.HeadRatio
			if c.HeadSheet == "" {
				headR = imageRatio(ns.Source, firstNonEmpty(c.Head, c.Note))
			}
			c.HoldStop = -ns.NoteW * headR * ns.NoteHS / 2
			if c.Tail != "" {
				name := fmt.Sprintf("end-%d.png", i+1)
				body := ""
				if c.Body != "" {
					body = filepath.Join(ns.Source, c.Body)
				} else if c.BodyGen != "" && c.BodyFit {
					body = filepath.Join(root, filepath.FromSlash(strings.TrimPrefix(c.BodyGen, "/")))
				}
				if err := writeQuaverEnd(filepath.Join(ns.Source, c.Tail), body, filepath.Join(dir, name)); err == nil {
					c.Tail = "/" + filepath.ToSlash(rel) + "/" + name
					keepAdd(keep, rel+"/"+name)
				} else {
					logf("noteskin %s: hold end %d: %v", ns.Name, i+1, err)
				}
			}
		}
		// osu!: a tall repeating body whose top is the hold's styled end (osubody.go)
		for i := range ns.Cols {
			c := &ns.Cols[i]
			if ns.Quaver || !c.Repeat {
				continue
			}
			src := c.bodySrc
			if src == "" && c.Body != "" {
				src = filepath.Join(ns.Source, c.Body)
			}
			if src == "" || imagePixelHeight(src) < 2048 {
				continue
			}
			w := ns.ColWidth
			if i < len(ns.ColW) {
				w = ns.ColW[i]
			}
			tail := ""
			if c.Tail != "" && !strings.HasPrefix(c.Tail, "/") {
				tail = filepath.Join(ns.Source, c.Tail)
			}
			endName, bodyName := fmt.Sprintf("end-%d.png", i+1), fmt.Sprintf("body-%d.png", i+1)
			ratio, ok := writeOsuBodyEnd(src, tail, filepath.Join(dir, endName), filepath.Join(dir, bodyName), w/maniaScale*osuStableScale, c.NoteHS)
			if !ok {
				continue
			}
			c.Body, c.bodySrc, c.BodyColour = "", "", nil
			c.BodyGen, c.BodyFit, c.Stretch = "/"+filepath.ToSlash(rel)+"/"+bodyName, true, true
			c.Tail, c.TailRatio = "/"+filepath.ToSlash(rel)+"/"+endName, ratio
			keepAdd(keep, rel+"/"+endName)
			keepAdd(keep, rel+"/"+endName+".ver")
			keepAdd(keep, rel+"/"+bodyName)
		}
		for i := range ns.Cols {
			c := &ns.Cols[i]
			if c.BodyColour == nil && c.bodySrc == "" {
				continue
			}
			name := fmt.Sprintf("body-%d.png", i+1)
			// the skin's own body, shrunk (or converted to PNG) so Etterna can use it: it keeps its
			// look, and is stretched over each hold the way osu! squeezes such tall bodies
			if c.bodySrc != "" {
				if err := writeShrunkPNG(c.bodySrc, filepath.Join(dir, name)); err == nil {
					c.BodyGen = "/" + filepath.ToSlash(rel) + "/" + name
					c.BodyFit = true
					c.Stretch = true
					keepAdd(keep, rel+"/"+name)
					continue
				} else {
					logf("noteskin: %s: hold body can't be converted (%v)", ns.Name, err)
					c.colourFrom(ns.Source, c.Head, c.Note)
				}
			}
			if c.BodyColour == nil {
				continue
			}
			if err := writeSolidPNG(filepath.Join(dir, name), *c.BodyColour); err == nil {
				c.BodyGen = "/" + filepath.ToSlash(rel) + "/" + name
				keepAdd(keep, rel+"/"+name)
			}
		}
		// the hold's end image turned over: Etterna can't turn hold caps itself (it resets their
		// texture each frame), and osu! / Quaver turn theirs depending on the scroll direction
		for i := range ns.Cols {
			c := &ns.Cols[i]
			if c.Tail == "" {
				continue
			}
			name := fmt.Sprintf("tail-%d.png", i+1)
			src := filepath.Join(ns.Source, c.Tail)
			if strings.HasPrefix(c.Tail, "/") { // written by VSRG Hub (Quaver's end with its body under it)
				src = filepath.Join(root, filepath.FromSlash(strings.TrimPrefix(c.Tail, "/")))
			}
			if err := writeFlippedPNG(src, filepath.Join(dir, name)); err == nil {
				c.TailFlipped = "/" + filepath.ToSlash(rel) + "/" + name
				keepAdd(keep, rel+"/"+name)
			}
		}
		// hold bodies and ends at power-of-two sizes (see potCopy): Etterna draws them right up to
		// their edges, where an image of any other size picks up a line of leftover texture memory
		for i := range ns.Cols {
			c := &ns.Cols[i]
			abs := func(p string) string {
				if strings.HasPrefix(p, "/") {
					return filepath.Join(root, filepath.FromSlash(strings.TrimPrefix(p, "/")))
				}
				return filepath.Join(ns.Source, p)
			}
			pot := func(p, kind string) (string, float64) {
				if p == "" {
					return p, 0
				}
				name := fmt.Sprintf("%s-%d.png", kind, i+1)
				r, ok, err := potCopy(abs(p), filepath.Join(dir, name))
				if err != nil {
					logf("noteskin %s: %s %d: %v", ns.Name, kind, i+1, err)
				}
				if !ok {
					return p, 0
				}
				keepAdd(keep, rel+"/"+name)
				return "/" + filepath.ToSlash(rel) + "/" + name, r
			}
			// a body that is the same all the way down (osu!'s tall "Percy" bodies VSRG Hub cut a
			// plain slice from, solid bodies...) repeats instead of stretching: it looks the same, and
			// Etterna draws a stretched body from its far end in batches with a missing step between
			// them, a small cut across holds longer than about five screens (wrapped bodies are
			// drawn from the screen's edge, so the cut never reaches the screen)
			if c.Stretch {
				b := c.Body
				if b == "" {
					b = c.BodyGen
				}
				if b != "" && imageRowsPlain(abs(b)) {
					c.Stretch = false
				}
			}
			if c.Body != "" {
				c.Body, c.BodyR = pot(c.Body, "potbody")
			} else if c.BodyGen != "" {
				c.BodyGen, c.BodyR = pot(c.BodyGen, "potbody")
			}
			var rT, rF float64
			c.Tail, rT = pot(c.Tail, "pottail")
			c.TailFlipped, rF = pot(c.TailFlipped, "pottailf")
			c.TailR = max(rT, rF)
		}
		// grey copies of every piece of art, for Customize gameplay's colours (greys.go)
		for i := range ns.Cols {
			c := &ns.Cols[i]
			c.Grey = map[string]string{}
			for k, p := range map[string]string{"note": c.Note, "noteS": c.NoteSheet, "head": c.Head, "headS": c.HeadSheet,
				"body": firstNonEmpty(c.Body, c.BodyGen), "tail": c.Tail, "tailF": c.TailFlipped, "key": c.Key, "keyD": c.KeyD, "mine": c.Mine} {
				if g := greyFor(root, ns.Source, rel, dir, p, keep); g != "" {
					c.Grey[k] = g
				}
			}
		}
		ns.Grey = map[string]string{}
		skinArt := map[string]string{"hint": ns.Hint, "colLight": ns.ColLight}
		if ns.LightN != nil {
			skinArt["lightN"] = ns.LightN.File
		}
		if ns.LightL != nil {
			skinArt["lightL"] = ns.LightL.File
		}
		if ns.HitLight != nil {
			skinArt["hitLight"] = ns.HitLight.File
		}
		if ns.HoldLight != nil {
			skinArt["holdLight"] = ns.HoldLight.File
		}
		for k, p := range skinArt {
			if g := greyFor(root, ns.Source, rel, dir, p, keep); g != "" {
				ns.Grey[k] = g
			}
		}
		// (the coloured copies of hold art made while the game ran stay: greys.go's serveTints)
		if tints, _ := filepath.Glob(filepath.Join(dir, "tint-*.png")); len(tints) > 0 {
			for _, t := range tints {
				keepAdd(keep, rel+"/"+filepath.Base(t))
			}
		}
		writeIfChanged(filepath.Join(dir, "NoteSkin.lua"), strings.Replace(noteSkinTemplate, "SKIN_DATA", ns.lua(), 1))
		writeIfChanged(filepath.Join(dir, "metrics.ini"), noteSkinMetrics+ns.stretchMetrics())
		for _, f := range []string{"", "/src", "/NoteSkin.lua", "/metrics.ini"} {
			keepAdd(keep, rel+f)
		}
	}
	keepAdd(keep, "NoteSkins")
	keepAdd(keep, "NoteSkins/dance")
	keepAdd(keep, "NoteSkins/kb7")
	return
}

// stretchMetrics turns on Etterna's stretched hold bodies for the columns whose skin stretches them.
func (ns noteSkin) stretchMetrics() string {
	buttons := map[string][]string{"dance": {"Left", "Down", "Up", "Right"}, "kb7": {"Key1", "Key2", "Key3", "Key4", "Key5", "Key6", "Key7"}}[ns.Game]
	var sb strings.Builder
	for i, c := range ns.Cols {
		if i >= len(buttons) {
			break
		}
		var lines []string
		if c.Stretch {
			lines = append(lines, "UseStretchHolds=1")
		}
		// the end image sits inside the hold, its far edge on the hold's end (as osu! and Quaver
		// draw it), so the body stops one end-image height short of the end
		if ns.Quaver {
			lines = append(lines, fmt.Sprintf("StopDrawingHoldBodyOffsetFromTail=%d", int(math.Round(c.HoldStop))))
		} else if c.Tail != "" && c.TailRatio > 0 {
			w := ns.ColWidth
			if i < len(ns.ColW) {
				w = ns.ColW[i]
			}
			if c.NoteHS > 0 {
				w *= c.NoteHS
			}
			lines = append(lines, fmt.Sprintf("StopDrawingHoldBodyOffsetFromTail=%d", -int(math.Round(w*c.TailRatio))))
		}
		// a picture per beat snap: Etterna moves the texture down one picture per snap (4th, 8th,
		// 12th, 16th, 24th, 32nd, 48th, 64th, 192nd: Quaver's 1/1 ... 1/16, 1/48)
		for _, p := range []struct {
			part         string
			slots, count int
		}{{"TapNote", c.NoteSlots, c.NoteCount}, {"HoldHead", c.HeadSlots, c.HeadCount}} {
			if p.slots > 1 && p.count > 1 {
				lines = append(lines, fmt.Sprintf("%sNoteColorTextureCoordSpacingY=%s", p.part, luaNum(1/float64(p.slots))),
					fmt.Sprintf("%sNoteColorCount=%d", p.part, min(p.count, 9)),
					p.part+"NoteColorType=Denominator")
			}
		}
		if len(lines) > 0 {
			fmt.Fprintf(&sb, "\n[%s]\n%s\n", buttons[i], strings.Join(lines, "\n"))
		}
	}
	return sb.String()
}

// writeShrunkPNG decodes a hold body Etterna can't load (too tall, or not really a PNG) and writes
// it as a PNG no taller than 2048 pixels and no wider than 256, only when it changed.
func writeShrunkPNG(src, dst string) error {
	// already converted from this very file: decoding a 40000-pixel image takes a while, so the
	// result is kept and only redone when the skin's image changes
	if si, err := os.Stat(src); err == nil {
		if di, err := os.Stat(dst); err == nil && !di.ModTime().Before(si.ModTime()) && di.Size() > 0 {
			return nil
		}
	}
	fh, err := os.Open(src)
	if err != nil {
		return err
	}
	img, _, err := image.Decode(fh)
	fh.Close()
	if err != nil {
		return err
	}
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h <= 0 {
		return fmt.Errorf("empty image")
	}
	// (each side on its own: the body is stretched over the hold anyway, so its proportions don't
	// matter, and squeezing the width with the height would blur it)
	nw, nh := min(w, 256), min(h, 2048)
	out := image.NewNRGBA(image.Rect(0, 0, nw, max(1, nh)))
	draw.CatmullRom.Scale(out, out.Bounds(), img, b, draw.Src, nil)
	return writePNGIfChanged(dst, out)
}

// imageRowsPlain reports whether every row of an image is the same (within a little rounding), so
// repeating it down a hold looks the same as stretching it.
func imageRowsPlain(path string) bool {
	if v, ok := plainMemo[path]; ok {
		return v
	}
	v := imageRowsPlainUncached(path)
	plainMemo[path] = v
	return v
}

var plainMemo = map[string]bool{}

func imageRowsPlainUncached(path string) bool {
	img, err := decodeFile(path)
	if err != nil {
		return false
	}
	b := img.Bounds()
	if b.Dx() <= 0 || b.Dy() <= 0 || b.Dy() > 4096 {
		return false
	}
	ref := b.Min.Y + b.Dy()/2
	const tol = 6 * 257
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			r1, g1, b1, a1 := img.At(x, y).RGBA()
			r2, g2, b2, a2 := img.At(x, ref).RGBA()
			if diff(r1, r2) > tol || diff(g1, g2) > tol || diff(b1, b2) > tol || diff(a1, a2) > tol {
				return false
			}
		}
	}
	return true
}

// potCopy writes src at the nearest power-of-two size up (at most 2048 a side) when it isn't one
// already, and returns its own height over width. Etterna puts an image of any other size into a
// bigger power-of-two texture whose rest is left as it was in memory; hold bodies and ends are drawn
// right up to their edges (and bodies repeat, wrapping around the texture), so they picked up a
// line of that leftover (random coloured dots) beside the hold. ok is false when src is used as it
// is (already a power of two, or unreadable).
func potCopy(src, dst string) (ratio float64, ok bool, err error) {
	fh, err := os.Open(src)
	if err != nil {
		return 0, false, err
	}
	cfg, _, err := image.DecodeConfig(fh)
	fh.Close()
	if err != nil {
		return 0, false, err
	}
	w, h := cfg.Width, cfg.Height
	if w <= 0 || h <= 0 {
		return 0, false, fmt.Errorf("empty image")
	}
	ratio = float64(h) / float64(w)
	nw, nh := nextPow2(min(w, 2048)), nextPow2(min(h, 2048))
	if nw == w && nh == h {
		return ratio, false, nil
	}
	// (already written from this very file)
	if si, err := os.Stat(src); err == nil {
		if di, err := os.Stat(dst); err == nil && !di.ModTime().Before(si.ModTime()) && di.Size() > 0 {
			return ratio, true, nil
		}
	}
	fh, err = os.Open(src)
	if err != nil {
		return 0, false, err
	}
	img, _, err := image.Decode(fh)
	fh.Close()
	if err != nil {
		return 0, false, err
	}
	out := image.NewNRGBA(image.Rect(0, 0, nw, nh))
	draw.CatmullRom.Scale(out, out.Bounds(), img, img.Bounds(), draw.Src, nil)
	if err := writePNGIfChanged(dst, out); err != nil {
		return 0, false, err
	}
	return ratio, true, nil
}

// writeFlippedPNG writes src upside down as a PNG, only when src changed since the last time.
func writeFlippedPNG(src, dst string) error {
	if si, err := os.Stat(src); err == nil {
		if di, err := os.Stat(dst); err == nil && !di.ModTime().Before(si.ModTime()) && di.Size() > 0 {
			return nil
		}
	}
	f, err := os.Open(src)
	if err != nil {
		return err
	}
	img, _, err := image.Decode(f)
	f.Close()
	if err != nil {
		return err
	}
	b := img.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			out.Set(x, b.Dy()-1-y, img.At(b.Min.X+x, b.Min.Y+y))
		}
	}
	return writePNGIfChanged(dst, out)
}

// writeSolidPNG writes a small image of one colour (a stand-in hold body), only when it changed.
func writeSolidPNG(path string, c color.NRGBA) error {
	img := image.NewNRGBA(image.Rect(0, 0, 32, 32))
	for i := 0; i < len(img.Pix); i += 4 {
		img.Pix[i], img.Pix[i+1], img.Pix[i+2], img.Pix[i+3] = c.R, c.G, c.B, c.A
	}
	return writePNGIfChanged(path, img)
}

func writePNGIfChanged(path string, img image.Image) error {
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return err
	}
	if old, err := os.ReadFile(path); err == nil && bytes.Equal(old, buf.Bytes()) {
		return nil
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func writeIfChanged(path, content string) error {
	if b, err := os.ReadFile(path); err == nil && string(b) == content {
		return nil
	}
	return os.WriteFile(path, []byte(content), 0o644)
}

// Etterna keeps the noteskin inside its modifier string ("1.5x, C700, mynoteskin"), which splits
// on spaces and commas: a noteskin name with a space can't be picked in Etterna's options or saved
// to the profile. VSRG Hub's noteskin names use underscores instead.
const osuNoteSkinPrefix = "osu!_"

func noteSkinSafe(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(asciiName(s), " ", "_"), ",", "_")
}

// asciiName keeps noteskin names to characters Etterna's noteskin list handles everywhere.
func asciiName(s string) string {
	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', strings.ContainsRune(" -_()[]!.'+&", r):
			b.WriteRune(r)
		default:
			b.WriteRune('_')
		}
	}
	out := strings.Join(strings.Fields(strings.Trim(b.String(), " ._")), " ")
	for strings.Contains(out, "__") {
		out = strings.ReplaceAll(out, "__", "_")
	}
	if out == "" {
		out = "skin"
	}
	return out
}

// osuLight is an osu!mania lighting animation: LightingN flashes over the hit line when a note is
// hit, LightingL glows there while a hold is held (osu! draws both additively).
type osuLight struct {
	frames   []string // the animation's pictures (name-0, name-1... or the single name)
	File     string   // the pictures side by side, written by VSRG Hub ("name Nx1.png"), Etterna path
	Frames   int
	FrameLen float64 // seconds per picture (osu!: 170 ms spread over the pictures, at least 1/60 s)
	PxScale  float64 // Etterna pixels per picture pixel (osu! draws them at their own size, @2x halved)
}

// osuFrames lists an animated element's pictures the way osu! finds them.
func osuFrames(files skinFiles, name string) []string {
	var out []string
	for i := 0; ; i++ {
		f := files.image(fmt.Sprintf("%s-%d", name, i))
		if f == "" {
			break
		}
		out = append(out, f)
	}
	if len(out) == 0 {
		if f := files.image(name); f != "" {
			out = []string{f}
		}
	}
	return out
}

func osuLighting(files skinFiles, skinDir, name string) *osuLight {
	fr := osuFrames(files, name)
	for _, f := range fr {
		if tooLarge(filepath.Join(skinDir, f)) {
			return nil
		}
	}
	if len(fr) == 0 || len(fr) > 64 {
		return nil
	}
	l := &osuLight{frames: fr, Frames: len(fr), FrameLen: max(1.0/60, 0.17/float64(len(fr))), PxScale: 480.0 / 768}
	if strings.Contains(strings.ToLower(fr[0]), "@2x") {
		l.PxScale /= 2
	}
	return l
}

// write puts the pictures side by side in one image Etterna splits into its frames.
func (l *osuLight) write(skinDir, dir, rel, kind string, keep map[string]bool) {
	name := fmt.Sprintf("%s %dx1.png", kind, len(l.frames))
	dst := filepath.Join(dir, name)
	fresh := false
	if di, err := os.Stat(dst); err == nil && di.Size() > 0 {
		fresh = true
		for _, f := range l.frames {
			if si, err := os.Stat(filepath.Join(skinDir, f)); err != nil || si.ModTime().After(di.ModTime()) {
				fresh = false
			}
		}
	}
	if !fresh {
		var imgs []image.Image
		for _, f := range l.frames {
			img, err := decodeFile(filepath.Join(skinDir, f))
			if err != nil {
				return
			}
			imgs = append(imgs, img)
		}
		b := imgs[0].Bounds()
		fw, fh := b.Dx(), b.Dy()
		if fw <= 0 || fh <= 0 || fw*len(imgs) > 8192 {
			return
		}
		out := image.NewNRGBA(image.Rect(0, 0, fw*len(imgs), fh))
		for i, img := range imgs {
			draw.CatmullRom.Scale(out, image.Rect(i*fw, 0, (i+1)*fw, fh), img, img.Bounds(), draw.Src, nil)
		}
		if writePNGIfChanged(dst, out) != nil {
			return
		}
	}
	l.File = "/" + filepath.ToSlash(rel) + "/" + name
	keepAdd(keep, rel+"/"+name)
}

func (l *osuLight) lua() string {
	if l == nil || l.File == "" {
		return "nil"
	}
	return fmt.Sprintf("{ file = %s, n = %d, frameLen = %s, px = %s }", luaStr(l.File), l.Frames, luaNum(math.Round(l.FrameLen*10000)/10000), luaNum(l.PxScale))
}

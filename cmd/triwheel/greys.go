package main

// Colours in Customize gameplay: a part of the noteskin (notes, hold heads, bodies and ends,
// receptors, the stage hint, the lighting) can be given a colour of the player's. A tint on the
// art as it is would only darken it (a purple note tinted red goes brown), so each piece of art
// gets a grey copy keeping its shading and transparency, and the game draws that copy tinted in
// the chosen colour. The copies are listed in the noteskin's data at launch and made here in the
// background (the first launch after an update does them all; later ones only new art), kept
// next to the noteskin as grey-<name>.png. Until a copy exists the game tints the original.

import (
	"bytes"
	"image"
	"image/color"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

type greyJob struct{ src, dst string }

// greyVersion changes whenever greyImage's output changes: older copies are made again.
const greyVersion = "2"

var (
	greyMu    sync.Mutex
	greyQueue []greyJob
	greyBusy  bool
)

// greyName is the grey copy's file name for a piece of art: the art's own name (a sheet keeps its
// " CxR" frame suffix, which Etterna reads from the name), with the skin's folders folded in.
func greyName(p string) string {
	base := p
	if strings.HasPrefix(p, "/") {
		base = path.Base(p)
	} else {
		base = strings.NewReplacer("/", "_", "\\", "_").Replace(p)
	}
	ext := path.Ext(base)
	return "grey-" + strings.TrimSuffix(base, ext) + ".png"
}

// greyFor queues the grey copy of art p (a path as the noteskin's data has it: relative to the
// skin's source, or absolute under the root) and returns the copy's path for the data.
func greyFor(root, source, rel, dir, p string, keep map[string]bool) string {
	if p == "" {
		return ""
	}
	src := filepath.Join(source, p)
	if strings.HasPrefix(p, "/") {
		src = filepath.Join(root, filepath.FromSlash(strings.TrimPrefix(p, "/")))
	}
	name := greyName(p)
	keepAdd(keep, rel+"/"+name)
	keepAdd(keep, rel+"/grey.ver")
	greyMu.Lock()
	greyQueue = append(greyQueue, greyJob{src, filepath.Join(dir, name)})
	greyMu.Unlock()
	return "/" + filepath.ToSlash(rel) + "/" + name
}

// makeGreys writes the queued copies that are missing or older than their art. It runs in the
// background while the game starts.
func makeGreys() {
	greyMu.Lock()
	if greyBusy {
		greyMu.Unlock()
		return
	}
	greyBusy = true
	jobs := greyQueue
	greyQueue = nil
	greyMu.Unlock()
	defer func() { greyMu.Lock(); greyBusy = false; greyMu.Unlock() }()
	start := time.Now()
	made, failed := 0, 0
	done := map[string]bool{}
	// (a folder whose copies were made by an older greyImage: all of them again)
	stale := map[string]bool{}
	for _, j := range jobs {
		dir := filepath.Dir(j.dst)
		if _, seen := stale[dir]; !seen {
			v, _ := os.ReadFile(filepath.Join(dir, "grey.ver"))
			stale[dir] = string(v) != greyVersion
		}
	}
	for _, j := range jobs {
		if done[j.dst] {
			continue
		}
		done[j.dst] = true
		si, err := os.Stat(j.src)
		if err != nil {
			continue
		}
		if di, err := os.Stat(j.dst); err == nil && !di.ModTime().Before(si.ModTime()) && di.Size() > 0 && !stale[filepath.Dir(j.dst)] {
			continue
		}
		img, err := decodeFile(j.src)
		if err != nil {
			failed++
			continue
		}
		if err := writePNGIfChanged(j.dst, greyImage(img)); err != nil {
			failed++
			continue
		}
		made++
	}
	for dir := range stale {
		os.WriteFile(filepath.Join(dir, "grey.ver"), []byte(greyVersion), 0o644)
	}
	if made > 0 || failed > 0 {
		logf("colours: %d grey copies of skin art made, %d couldn't be, in %s", made, failed, time.Since(start).Round(time.Millisecond))
	}
}

// greyImage is img in grey (its brightness), with its transparency as it was, brightened so its
// light parts are white: a saturated colour is dark in grey (a pure blue is a quarter as bright as
// white), and tinting that grey in red would give a dark red, not the red picked. The brightness
// almost all of the picture's pixels stay under (the brightest 2% are left out: highlights) is
// taken as full.
func greyImage(img image.Image) *image.NRGBA {
	b := img.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	var hist [256]int
	n := 0
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			c := color.NRGBAModel.Convert(img.At(x, y)).(color.NRGBA)
			l := (299*uint32(c.R) + 587*uint32(c.G) + 114*uint32(c.B)) / 1000
			i := out.PixOffset(x-b.Min.X, y-b.Min.Y)
			out.Pix[i], out.Pix[i+1], out.Pix[i+2], out.Pix[i+3] = uint8(l), uint8(l), uint8(l), c.A
			if c.A >= 128 {
				hist[l]++
				n++
			}
		}
	}
	if n == 0 {
		return out
	}
	top, seen := 255, 0
	for v := 255; v >= 0; v-- {
		seen += hist[v]
		if seen > n/50 {
			top = v
			break
		}
	}
	if top >= 250 || top < 8 {
		return out
	}
	for i := 0; i < len(out.Pix); i += 4 {
		l := min(255, int(out.Pix[i])*255/top)
		out.Pix[i], out.Pix[i+1], out.Pix[i+2] = uint8(l), uint8(l), uint8(l)
	}
	return out
}

// serveTints makes the coloured copies of hold art the game asks for while it runs (Etterna
// draws hold bodies and ends from their texture alone, so a colour has to be in the picture):
// Save/VSRGHub/colours/want.txt lists "art<TAB>copy<TAB>#rrggbbaa" lines, paths as Etterna has
// them (/NoteSkins/<game>/<skin>/...). Each copy is the art (its grey copy when there is one)
// multiplied by the colour, alpha included. Called from the online service's tick.
func serveTints(data string) {
	p := filepath.Join(data, "colours", "want.txt")
	b, err := os.ReadFile(p)
	if err != nil || len(bytes.TrimSpace(b)) == 0 {
		return
	}
	root := filepath.Join(filepath.Dir(filepath.Dir(data)), "VSRGHub", "Root")
	made := 0
	for _, line := range strings.Split(string(b), "\n") {
		f := strings.Split(strings.TrimSpace(line), "\t")
		if len(f) != 3 || !strings.HasPrefix(f[0], "/NoteSkins/") || !strings.HasPrefix(f[1], "/NoteSkins/") || strings.Contains(f[1], "..") {
			continue
		}
		dst := filepath.Join(root, filepath.FromSlash(strings.TrimPrefix(f[1], "/")))
		if _, err := os.Stat(dst); err == nil {
			continue
		}
		col, ok := parseHexColour(f[2])
		if !ok {
			continue
		}
		img, err := decodeFile(filepath.Join(root, filepath.FromSlash(strings.TrimPrefix(f[0], "/"))))
		if err != nil {
			logf("colours: %s: %v", f[0], err)
			continue
		}
		if err := writePNGIfChanged(dst, tintImage(img, col)); err != nil {
			logf("colours: %s: %v", f[1], err)
			continue
		}
		made++
	}
	if made > 0 {
		logf("colours: %d coloured copies of hold art made", made)
	}
}

// parseHexColour reads "#rrggbb" or "#rrggbbaa".
func parseHexColour(s string) (color.NRGBA, bool) {
	s = strings.TrimPrefix(strings.TrimSpace(s), "#")
	if len(s) != 6 && len(s) != 8 {
		return color.NRGBA{}, false
	}
	var v [4]uint8 = [4]uint8{0, 0, 0, 255}
	for i := 0; i < len(s)/2; i++ {
		n, err := strconv.ParseUint(s[2*i:2*i+2], 16, 8)
		if err != nil {
			return color.NRGBA{}, false
		}
		v[i] = uint8(n)
	}
	return color.NRGBA{v[0], v[1], v[2], v[3]}, true
}

// tintImage is img with every pixel multiplied by col (alpha too).
func tintImage(img image.Image, col color.NRGBA) *image.NRGBA {
	b := img.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			c := color.NRGBAModel.Convert(img.At(x, y)).(color.NRGBA)
			i := out.PixOffset(x-b.Min.X, y-b.Min.Y)
			out.Pix[i] = uint8(uint32(c.R) * uint32(col.R) / 255)
			out.Pix[i+1] = uint8(uint32(c.G) * uint32(col.G) / 255)
			out.Pix[i+2] = uint8(uint32(c.B) * uint32(col.B) / 255)
			out.Pix[i+3] = uint8(uint32(c.A) * uint32(col.A) / 255)
		}
	}
	return out
}

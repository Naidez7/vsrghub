package main

// Colours in Customize gameplay: a part of the noteskin (notes, hold heads, bodies and ends,
// receptors, the stage hint, the lighting) can be given a colour of the player's. A tint on the
// art as it is would only darken it (a purple note tinted red goes brown), so each piece of art
// gets a grey copy keeping its shading and transparency, and the game draws that copy tinted in
// the chosen colour. The copies are listed in the noteskin's data at launch and made here in the
// background (the first launch after an update does them all; later ones only new art), kept
// next to the noteskin as grey-<name>.png. Until a copy exists the game tints the original.

import (
	"image"
	"image/color"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type greyJob struct{ src, dst string }

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
	for _, j := range jobs {
		if done[j.dst] {
			continue
		}
		done[j.dst] = true
		si, err := os.Stat(j.src)
		if err != nil {
			continue
		}
		if di, err := os.Stat(j.dst); err == nil && !di.ModTime().Before(si.ModTime()) && di.Size() > 0 {
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
	if made > 0 || failed > 0 {
		logf("colours: %d grey copies of skin art made, %d couldn't be, in %s", made, failed, time.Since(start).Round(time.Millisecond))
	}
}

// greyImage is img in grey (its brightness), with its transparency as it was.
func greyImage(img image.Image) *image.NRGBA {
	b := img.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			c := color.NRGBAModel.Convert(img.At(x, y)).(color.NRGBA)
			l := uint8((299*uint32(c.R) + 587*uint32(c.G) + 114*uint32(c.B)) / 1000)
			i := out.PixOffset(x-b.Min.X, y-b.Min.Y)
			out.Pix[i], out.Pix[i+1], out.Pix[i+2], out.Pix[i+3] = l, l, l, c.A
		}
	}
	return out
}

package main

// osu!'s repeating hold bodies (NoteBodyStyle 1 and 2) are drawn from the hold's end: the top of
// the body image sits on the end of the hold and the image runs down towards the head at the
// scale that fits its width to the column, repeating when the hold is longer than it.
// Many skins use that for the hold's tail: the body is one very tall image (tens of thousands of
// pixels) whose top is the rounded or styled end of the hold, and the rest a plain strip. Etterna
// can't load such an image, and stretching a shrunk copy over each hold flattens that end away.
// For those bodies VSRG Hub cuts the image in two: the styled end becomes the hold's end image, at
// the size osu! draws it, and a slice of the plain strip becomes the body.

import (
	"image"
	"image/draw"
	"math"
	"os"

	xdraw "golang.org/x/image/draw"
)

// osuBodyVersion changes whenever the split's output changes, so older splits are redone.
const osuBodyVersion = "2"

// osuStableScale turns osu!mania skin.ini sizes (480-tall) into osu!'s 768-tall units.
const osuStableScale = 768.0 / 480

// bodyEndRows is how many rows at the top of a body image differ from its plain middle (0 when the
// whole image is plain), looking at most at the first half of the image.
func bodyEndRows(img image.Image) int {
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h < 4 {
		return 0
	}
	ref := b.Min.Y + h/2
	same := func(y int) bool {
		for x := b.Min.X; x < b.Max.X; x++ {
			r1, g1, b1, a1 := img.At(x, y).RGBA()
			r2, g2, b2, a2 := img.At(x, ref).RGBA()
			const tol = 6 * 257
			if diff(r1, r2) > tol || diff(g1, g2) > tol || diff(b1, b2) > tol || diff(a1, a2) > tol {
				return false
			}
		}
		return true
	}
	last := -1
	limit := min(h/2, 8192)
	for y := 0; y < limit; y++ {
		if !same(b.Min.Y + y) {
			last = y
		}
	}
	return last + 1
}

func diff(a, b uint32) uint32 {
	if a > b {
		return a - b
	}
	return b - a
}

// writeOsuBodyEnd splits a tall repeating osu! hold body (src) into the hold's end image (endDst:
// the body's styled top turned over for Etterna's upscroll, with the skin's own tail image on it
// when that has anything to show) and a plain body slice (bodyDst). colUnits is the column's width
// in osu!'s 768-tall units, hs how much taller than their picture the column's notes are drawn
// (VSRG Hub's Lua draws the end image that much taller, so it is taken out here), tail the skin's
// tail image ("" for none). It returns the end image's height over its width; ok is false when the
// body has no styled end (or one too small or too big to be one), and nothing is written then.
func writeOsuBodyEnd(src, tail, endDst, bodyDst string, colUnits, hs float64) (ratio float64, ok bool) {
	if hs <= 0 {
		hs = 1
	}
	// already split from this very file, by this version of the split (a sidecar notes which)
	verFile := endDst + ".ver"
	if si, err := os.Stat(src); err == nil {
		if v, err := os.ReadFile(verFile); err != nil || string(v) != osuBodyVersion {
			si = nil
		}
		if ei, err := os.Stat(endDst); si != nil && err == nil && !ei.ModTime().Before(si.ModTime()) {
			if bi, err := os.Stat(bodyDst); err == nil && !bi.ModTime().Before(si.ModTime()) {
				if f, err := os.Open(endDst); err == nil {
					cfg, _, err := image.DecodeConfig(f)
					f.Close()
					if err == nil && cfg.Width > 0 {
						return float64(cfg.Height) / float64(cfg.Width), true
					}
				}
			}
		}
	}
	img, err := decodeFile(src)
	if err != nil {
		return 0, false
	}
	b := img.Bounds()
	texW, texH := b.Dx(), b.Dy()
	if texW <= 0 || texH < 2048 || colUnits <= 0 {
		return 0, false
	}
	k := bodyEndRows(img)
	if k == 0 {
		return 0, false
	}
	// the styled end's height in column widths, as osu! stable draws it: the body image scaled to
	// the column's width, its rows at that scale, run from the hold's end towards the head (not
	// stretched over the hold, however tall the image: a 102-wide image with a 44-row rounded top
	// ends in a half circle, whatever is under it)
	endCW := float64(k) / float64(texW)
	if endCW < 0.05 || endCW > 4 {
		return 0, false
	}
	outW := min(texW, 256)
	endH := max(1, int(math.Round(endCW*float64(outW)/hs)))
	// the skin's own tail, drawn over the end of the hold (when it shows anything)
	var tailImg image.Image
	tailH := 0
	if tail != "" && !isBlankImage(tail) {
		if t, err := decodeFile(tail); err == nil && t.Bounds().Dx() > 0 {
			tailImg = t
			tailH = max(1, int(math.Round(float64(t.Bounds().Dy())*float64(outW)/float64(t.Bounds().Dx()))))
		}
	}
	outH := max(endH, tailH)
	// the styled end, scaled, then turned over: in upscroll osu! draws the body turned over (its top
	// at the hold's end, which is at the bottom), and Etterna draws the end image as it is there
	scaled := image.NewNRGBA(image.Rect(0, 0, outW, endH))
	xdraw.CatmullRom.Scale(scaled, scaled.Bounds(), img, image.Rect(b.Min.X, b.Min.Y, b.Max.X, b.Min.Y+k), xdraw.Src, nil)
	out := image.NewNRGBA(image.Rect(0, 0, outW, outH))
	for y := 0; y < endH; y++ {
		// row y of the end (0 = the hold's very end) goes to the bottom of the image
		dy := outH - 1 - y
		copy(out.Pix[dy*out.Stride:dy*out.Stride+outW*4], scaled.Pix[y*scaled.Stride:y*scaled.Stride+outW*4])
	}
	if tailImg != nil {
		// the tail as osu! draws it in upscroll: as it is, its far edge on the hold's end
		r := image.Rect(0, outH-tailH, outW, outH)
		xdraw.CatmullRom.Scale(out, r, tailImg, tailImg.Bounds(), draw.Over, nil)
	}
	if err := writePNGIfChanged(endDst, out); err != nil {
		return 0, false
	}
	// the plain strip: a slice from the middle (it is the same all the way down)
	sliceH := min(64, texH/4)
	mid := b.Min.Y + texH/2
	body := image.NewNRGBA(image.Rect(0, 0, outW, sliceH))
	xdraw.CatmullRom.Scale(body, body.Bounds(), img, image.Rect(b.Min.X, mid, b.Max.X, mid+sliceH), xdraw.Src, nil)
	if err := writePNGIfChanged(bodyDst, body); err != nil {
		return 0, false
	}
	os.WriteFile(verFile, []byte(osuBodyVersion), 0o644)
	return float64(outH) / float64(outW), true
}

// imagePixelHeight is an image file's height in pixels (0 when it can't be read).
func imagePixelHeight(path string) int {
	f, err := os.Open(path)
	if err != nil {
		return 0
	}
	defer f.Close()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return 0
	}
	return cfg.Height
}

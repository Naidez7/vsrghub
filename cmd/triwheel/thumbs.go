package main

// Small pictures for the song list. A song's background can be a 4K photo: loaded into a panel's
// corner it takes long to read and, shrunk that far by the graphics card, looks wrong (too many
// pixels in too little room). So each converted song gets a thumbnail of its background (at most
// 480×270, a jpg of a few dozen KB) in its own folder, which the looks' song panels show instead.
// The name carries Etterna's "mipmaps" hint: the game then shrinks it smoothly.

import (
	"bufio"
	"image"
	"image/color"
	"image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

const (
	thumbName = "vsrghub-thumb-mipmaps.jpg"
	thumbNone = "vsrghub-thumb.none" // (the background couldn't be read: not tried again until it changes)
	bigName   = "vsrghub-bg.jpg"     // a 1080p copy of a background bigger than 2048 px (the looks' screens load it instead)
	thumbW    = 480
	thumbH    = 270
	bigW      = 1920
	bigH      = 1080
	bigOver   = 2048
)

var thumbsBusy atomic.Bool

// the library's converted groups (main.go's convertGroup calls)
var thumbGroups = []string{"osu!", "Quaver"}

// makeThumbs writes the thumbnails missing or stale in the library's converted groups. It runs in
// the background (the game starts meanwhile, and shows the full pictures until each one is there).
func makeThumbs(lib string, groups []string) {
	if !thumbsBusy.CompareAndSwap(false, true) {
		return
	}
	defer thumbsBusy.Store(false)
	type job struct{ dir, src string }
	var jobs []job
	for _, g := range groups {
		songs, err := os.ReadDir(filepath.Join(lib, g))
		if err != nil {
			continue
		}
		for _, s := range songs {
			if !s.IsDir() {
				continue
			}
			dir := filepath.Join(lib, g, s.Name())
			bg := smBackground(filepath.Join(dir, s.Name()+".sm"))
			if bg == "" {
				continue
			}
			src := filepath.Join(dir, filepath.FromSlash(bg))
			st, err := os.Stat(src)
			if err != nil || st.IsDir() {
				continue
			}
			if fresh(filepath.Join(dir, thumbName), st.ModTime()) || fresh(filepath.Join(dir, thumbNone), st.ModTime()) {
				continue
			}
			jobs = append(jobs, job{dir, src})
		}
	}
	if len(jobs) == 0 {
		return
	}
	start := time.Now()
	var made, failed atomic.Int32
	ch := make(chan job)
	var wg sync.WaitGroup
	// (half the cores: the game is starting up alongside)
	for w := 0; w < max(1, runtime.NumCPU()/2); w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range ch {
				if err := writeThumb(j.src, filepath.Join(j.dir, thumbName), filepath.Join(j.dir, bigName)); err != nil {
					os.WriteFile(filepath.Join(j.dir, thumbNone), []byte(err.Error()+"\n"), 0o644)
					failed.Add(1)
				} else {
					os.Remove(filepath.Join(j.dir, thumbNone))
					made.Add(1)
				}
			}
		}()
	}
	for _, j := range jobs {
		ch <- j
	}
	close(ch)
	wg.Wait()
	logf("thumbnails: %d made, %d backgrounds couldn't be read, in %s", made.Load(), failed.Load(), time.Since(start).Round(time.Second))
}

// fresh: the file is there and newer than the background it was made from
func fresh(p string, srcTime time.Time) bool {
	st, err := os.Stat(p)
	return err == nil && !st.ModTime().Before(srcTime)
}

// smBackground reads #BACKGROUND from the head of a generated .sm (the notes come after it)
func smBackground(smPath string) string {
	f, err := os.Open(smPath)
	if err != nil {
		return ""
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for n := 0; sc.Scan() && n < 40; n++ {
		line := sc.Text()
		if strings.HasPrefix(line, "#BACKGROUND:") {
			v := strings.TrimSuffix(strings.TrimPrefix(line, "#BACKGROUND:"), ";")
			return smUnescape(v)
		}
	}
	return ""
}

func smUnescape(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] == '\\' && i+1 < len(s) {
			i++
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

// writeThumb shrinks the picture at src to fit 480×270 and writes it as a jpg at dst; a picture over
// 2048 px wide or tall also gets a copy fit to 1920×1080 at big (a smaller one doesn't need it).
func writeThumb(src, dst, big string) error {
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
	sw, sh := b.Dx(), b.Dy()
	if sw < 1 || sh < 1 {
		return os.ErrInvalid
	}
	if big != "" {
		if sw > bigOver || sh > bigOver {
			if err := writeFit(img, big, bigW, bigH, 88); err != nil {
				return err
			}
		} else {
			os.Remove(big)
		}
	}
	return writeFit(img, dst, thumbW, thumbH, 85)
}

// writeFit writes img shrunk to fit maxW×maxH as a jpg
func writeFit(img image.Image, dst string, maxW, maxH, quality int) error {
	b := img.Bounds()
	sw, sh := b.Dx(), b.Dy()
	thumbW, thumbH := maxW, maxH
	w, h := sw, sh
	if w > thumbW || h > thumbH {
		if float64(sw)/float64(sh) > float64(thumbW)/float64(thumbH) {
			w, h = thumbW, max(1, sh*thumbW/sw)
		} else {
			w, h = max(1, sw*thumbH/sh), thumbH
		}
	}
	// (a big picture is first shrunk by a whole number, averaging blocks of pixels: fast, and
	// what's left for the slower smooth scaler is small)
	if k := min(sw/w, sh/h); k >= 2 {
		img = boxShrink(img, k)
		b = img.Bounds()
		sw, sh = b.Dx(), b.Dy()
	}
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	if w == sw && h == sh {
		draw.Draw(out, out.Bounds(), img, b.Min, draw.Src)
	} else {
		draw.CatmullRom.Scale(out, out.Bounds(), img, b, draw.Src, nil)
	}
	tmp := dst + ".tmp"
	o, err := os.Create(tmp)
	if err != nil {
		return err
	}
	if err := jpeg.Encode(o, out, &jpeg.Options{Quality: quality}); err != nil {
		o.Close()
		os.Remove(tmp)
		return err
	}
	if err := o.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, dst)
}

// boxShrink averages k×k blocks of pixels into one (the picture's size divided by k)
func boxShrink(img image.Image, k int) *image.RGBA {
	b := img.Bounds()
	w, h := b.Dx()/k, b.Dy()/k
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	n := uint32(k * k)
	switch src := img.(type) {
	case *image.YCbCr:
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				var sy, scb, scr uint32
				for dy := 0; dy < k; dy++ {
					py := b.Min.Y + y*k + dy
					yi := src.YOffset(b.Min.X+x*k, py)
					for dx := 0; dx < k; dx++ {
						px := b.Min.X + x*k + dx
						sy += uint32(src.Y[yi+dx])
						ci := src.COffset(px, py)
						scb += uint32(src.Cb[ci])
						scr += uint32(src.Cr[ci])
					}
				}
				r, g, bl := color.YCbCrToRGB(uint8(sy/n), uint8(scb/n), uint8(scr/n))
				i := out.PixOffset(x, y)
				out.Pix[i], out.Pix[i+1], out.Pix[i+2], out.Pix[i+3] = r, g, bl, 255
			}
		}
	case *image.RGBA, *image.NRGBA:
		var pix []uint8
		var stride int
		if p, ok := src.(*image.RGBA); ok {
			pix, stride = p.Pix, p.Stride
		} else {
			p := src.(*image.NRGBA)
			pix, stride = p.Pix, p.Stride
		}
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				var sr, sg, sb uint32
				for dy := 0; dy < k; dy++ {
					i := (y*k+dy)*stride + x*k*4
					for dx := 0; dx < k; dx++ {
						sr += uint32(pix[i])
						sg += uint32(pix[i+1])
						sb += uint32(pix[i+2])
						i += 4
					}
				}
				o := out.PixOffset(x, y)
				out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = uint8(sr/n), uint8(sg/n), uint8(sb/n), 255
			}
		}
	default:
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				var sr, sg, sb uint32
				for dy := 0; dy < k; dy++ {
					for dx := 0; dx < k; dx++ {
						r, g, bl, _ := img.At(b.Min.X+x*k+dx, b.Min.Y+y*k+dy).RGBA()
						sr += r >> 8
						sg += g >> 8
						sb += bl >> 8
					}
				}
				o := out.PixOffset(x, y)
				out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = uint8(sr/n), uint8(sg/n), uint8(sb/n), 255
			}
		}
	}
	return out
}

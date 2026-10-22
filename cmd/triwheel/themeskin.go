package main

// Points the VSRG Hub osu! theme at the player's current osu! skin: a "skin"
// link to the skin folder plus a Lua table of which elements it has.

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

const themeName = "VSRG Hub osu!"

// the themes VSRG Hub can run (picked in its options, Ctrl+O): its own, and Etterna's two
const quaverThemeName = "VSRG Hub Quaver"
const lazerThemeName = "VSRG Hub lazer"

var etternaThemes = []string{"Til Death", "Rebirth"}

//go:embed assets/theme-switch.lua
var themeSwitchLua string

//go:embed assets/pause.lua
var pauseLua string

//go:embed assets/customize.lua
var customizeLua string

//go:embed assets/profile.lua
var profileLua string

//go:embed assets/keys.lua
var keysLua string

// pickedTheme is the theme chosen in VSRG Hub's options (Save/VSRGHub/settings.ini, theme=...).
func pickedTheme(root, etterna string) string {
	b, err := os.ReadFile(filepath.Join(etterna, "Save", "VSRGHub", "settings.ini"))
	if err != nil {
		return themeName
	}
	for _, l := range strings.Split(strings.ReplaceAll(string(b), "\r", ""), "\n") {
		if v, ok := strings.CutPrefix(l, "theme="); ok {
			v = strings.TrimSpace(v)
			switch {
			case v == themeName,
				v == quaverThemeName && dirExists(filepath.Join(root, "Themes", quaverThemeName)),
				v == lazerThemeName && dirExists(filepath.Join(root, "Themes", lazerThemeName)):
				return v
			}
			for _, t := range etternaThemes {
				if v == t && dirExists(filepath.Join(etterna, "Themes", t)) {
					return v
				}
			}
		}
	}
	return themeName
}

// devPrefs is set by -ldflags for test builds (ShowThemeErrors=1).
var devPrefs = ""

// isBlankImage reports whether an image is tiny or (almost) fully transparent.
func isBlankImage(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	if err != nil {
		return false
	}
	b := img.Bounds()
	if b.Dx() <= 4 && b.Dy() <= 4 {
		return true
	}
	// fine enough to catch a small glyph in a wide padded image (score-percent with the glyph
	// in its last 17 pixels) and faint art that osu! still shows (an alpha-8 HP bar)
	step := max(1, max(b.Dx(), b.Dy())/1024)
	visible := 0
	for y := b.Min.Y; y < b.Max.Y; y += step {
		for x := b.Min.X; x < b.Max.X; x += step {
			_, _, _, a := img.At(x, y).RGBA()
			if a > 0x0300 {
				visible++
				if visible > 2 {
					return false
				}
			}
		}
	}
	return true
}

// inkBox is where an image's visible part is: its first column as a share of its width, and its
// top and bottom rows as shares of its height.
func inkBox(path string) (left, top, bottom float64, ok bool) {
	f, err := os.Open(path)
	if err != nil {
		return 0, 0, 0, false
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	if err != nil {
		return 0, 0, 0, false
	}
	b := img.Bounds()
	if b.Dx() <= 0 || b.Dy() <= 0 {
		return 0, 0, 0, false
	}
	minX, minY, maxY := b.Max.X, b.Max.Y, b.Min.Y-1
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			if _, _, _, a := img.At(x, y).RGBA(); a > 0x0800 {
				if x < minX {
					minX = x
				}
				if y < minY {
					minY = y
				}
				if y > maxY {
					maxY = y
				}
			}
		}
	}
	if maxY < minY {
		return 0, 0, 0, false
	}
	r := func(v float64) float64 { return math.Round(v*1000) / 1000 }
	return r(float64(minX-b.Min.X) / float64(b.Dx())), r(float64(minY-b.Min.Y) / float64(b.Dy())),
		r(float64(maxY+1-b.Min.Y) / float64(b.Dy())), true
}

// displayName keeps a skin name to characters Etterna's fonts can draw.
func displayName(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= 0x20 && r < 0x250 {
			b.WriteRune(r)
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}

func luaNum(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }

// skinEntry builds the Lua table describing one osu! skin for the interface: which elements it
// has (files), which it blanks on purpose (blank), its colours, number-font overlaps and mania layout.
// dir is where the theme reaches the skin (a link under the theme's "skins" folder).
func skinEntry(skinDir, folder, dir string, noteSkins []noteSkin) string {
	files := indexSkin(skinDir)
	ini := readSkinIni(filepath.Join(skinDir, files.real("skin.ini")))
	get := func(section, key string) string {
		for _, s := range ini {
			if s.name == section {
				if v := s.kv[strings.ToLower(key)]; v != "" {
					return v
				}
			}
		}
		return ""
	}
	mania := map[int]map[string]string{}
	for _, s := range ini {
		if s.name == "mania" {
			if k, err := strconv.Atoi(strings.TrimSpace(s.kv["keys"])); err == nil && mania[k] == nil {
				mania[k] = s.kv // (osu! keeps the first section for a key count)
			}
		}
	}
	prefix := map[string]string{
		"ScorePrefix": firstNonEmpty(get("fonts", "ScorePrefix"), "score"),
		"ComboPrefix": firstNonEmpty(get("fonts", "ComboPrefix"), "score"),
	}
	// resolve finds an element's image: the path, or blank when the skin hides it on purpose (an
	// empty image: draw nothing, like osu!). keys picks the [Mania] section for stage art.
	resolve := func(el ThemeElementRow, keys int, quiet bool) (string, bool) {
		cands := strings.Split(el.Candidates, "|")
		if sec, key, ok := strings.Cut(el.IniKey, ":"); ok && sec == "Mania4" {
			v := mania[keys][strings.ToLower(key)]
			if v == "" && strings.HasPrefix(strings.ToLower(key), "hit") {
				// judgement art set only in another key count's section (some skins, like OFF
				// SCRIPT, blank the root hit images and keep theirs under [Mania]): use that
				var ks []int
				for k := range mania {
					ks = append(ks, k)
				}
				sort.Ints(ks)
				for _, k := range ks {
					if w := mania[k][strings.ToLower(key)]; w != "" && files.image(w) != "" {
						v = w
						break
					}
				}
			}
			if v != "" {
				cands = append([]string{v}, cands...)
			}
		}
		for _, c := range cands {
			for k, v := range prefix {
				c = strings.ReplaceAll(c, "{"+k+"}", v)
			}
			if p := files.image(c); p != "" {
				if tooLarge(filepath.Join(skinDir, p)) {
					if !quiet {
						logf("theme: %s can't be loaded by Etterna, left out", filepath.Join(folder, p))
					}
					return "", false
				}
				if isBlankImage(filepath.Join(skinDir, p)) {
					return "", true
				}
				return p, false
			}
		}
		return "", false
	}
	found := map[string]string{}
	blank := map[string]bool{}
	// stage art can differ between the 4K and 7K sections of skin.ini: 7K's own is kept apart
	found7 := map[string]string{}
	blank7 := map[string]bool{}
	for _, el := range ThemeElements {
		p, b := resolve(el, 4, false)
		if b {
			blank[el.ID] = true
		} else if p != "" {
			found[el.ID] = p
		}
		if strings.HasPrefix(el.IniKey, "Mania4:") {
			p7, b7 := resolve(el, 7, true)
			if p7 != p || b7 != b {
				if b7 {
					blank7[el.ID] = true
				} else {
					found7[el.ID] = p7 // "" when 7K has none
				}
			}
		}
	}
	if p := found["stage_bottom"]; p != "" {
		logf("theme: %s has a stage bottom / lane cover (%s)", folder, p)
	}
	sortedKeys := func(m map[string]bool) []string {
		var out []string
		for k := range m {
			out = append(out, k)
		}
		sort.Strings(out)
		return out
	}
	foundSet := map[string]bool{}
	for k := range found {
		foundSet[k] = true
	}
	var sb strings.Builder
	sb.WriteString("{\n\tname = " + luaStr(firstNonEmpty(displayName(get("general", "Name")), displayName(folder), "osu! skin")) + ",\n")
	sb.WriteString("\tfolder = " + luaStr(folder) + ",\n")
	sb.WriteString("\tauthor = " + luaStr(displayName(get("general", "Author"))) + ",\n")
	// skin.ini's Version: osu! stable lays song panels out differently before 2.2 (no thumbnails)
	skinVer := 1.0
	if v := strings.TrimSpace(get("general", "Version")); strings.EqualFold(v, "latest") {
		skinVer = 99
	} else if f, err := strconv.ParseFloat(v, 64); err == nil {
		skinVer = f
	}
	sb.WriteString("\tversion = " + luaNum(skinVer) + ",\n")
	sb.WriteString("\tdir = " + luaStr(dir) + ",\n\tfiles = {\n")
	for _, id := range sortedKeys(foundSet) {
		fmt.Fprintf(&sb, "\t\t%s = %s,\n", id, luaStr(found[id]))
	}
	sb.WriteString("\t},\n\thd = {")
	for _, id := range sortedKeys(foundSet) {
		if strings.Contains(strings.ToLower(found[id]), "@2x.") {
			fmt.Fprintf(&sb, " %s = true,", id)
		}
	}
	sb.WriteString(" },\n\tblank = {")
	for _, id := range sortedKeys(blank) {
		fmt.Fprintf(&sb, " %s = true,", id)
	}
	sb.WriteString(" },\n\tkeyed7 = { files = {")
	var ids7 []string
	for id := range found7 {
		ids7 = append(ids7, id)
	}
	sort.Strings(ids7)
	for _, id := range ids7 {
		if found7[id] == "" {
			fmt.Fprintf(&sb, " %s = false,", id)
		} else {
			fmt.Fprintf(&sb, " %s = %s,", id, luaStr(found7[id]))
		}
	}
	sb.WriteString(" }, hd = {")
	for _, id := range ids7 {
		if strings.Contains(strings.ToLower(found7[id]), "@2x.") {
			fmt.Fprintf(&sb, " %s = true,", id)
		}
	}
	sb.WriteString(" }, blank = {")
	for _, id := range sortedKeys(blank7) {
		fmt.Fprintf(&sb, " %s = true,", id)
	}
	sb.WriteString(" } },\n\tcolours = {\n")
	for _, k := range []string{"SongSelectActiveText", "SongSelectInactiveText", "MenuGlow", "InputOverlayText", "StarBreakAdditive"} {
		if v := get("colours", k); v != "" {
			if rgb, ok := parseRGB(v); ok {
				fmt.Fprintf(&sb, "\t\t%s = { %d, %d, %d },\n", k, rgb[0], rgb[1], rgb[2])
			}
		}
	}
	sb.WriteString("\t},\n")
	if a, ok := skinAccent(skinDir, files); ok {
		fmt.Fprintf(&sb, "\taccent = { %d, %d, %d },\n", a[0], a[1], a[2])
	}
	num := func(v string, def float64) float64 {
		v = strings.TrimSpace(strings.Split(v, ",")[0])
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
		return def
	}
	// the pointer: centred on the mouse (osu!'s default) or with its corner there, turning, growing on a click
	flag := func(k string, def bool) bool {
		v := strings.TrimSpace(get("general", k))
		if v == "" {
			return def
		}
		return v == "1" || strings.EqualFold(v, "true")
	}
	fmt.Fprintf(&sb, "\tcursorCentre = %v,\n\tcursorRotate = %v,\n\tcursorExpand = %v,\n\tcursorTrailRotate = %v,\n",
		flag("CursorCentre", true), flag("CursorRotate", true), flag("CursorExpand", true), flag("CursorTrailRotate", true))
	fmt.Fprintf(&sb, "\tscoreOverlap = %s,\n\tcomboOverlap = %s,\n", luaNum(num(get("fonts", "ScoreOverlap"), 0)), luaNum(num(get("fonts", "ComboOverlap"), 0)))
	// where a digit's ink starts across its image (0 = at its left edge): skins that pad each digit
	// far to the left and cancel that with a huge overlap are told apart from ones whose small
	// digits just overlap a lot
	// (and how high it sits: a minus for a negative accuracy goes at the digits' middle)
	for _, d := range []struct{ id, key string }{{"score_0", "score"}, {"combo_0", "combo"}} {
		if p := found[d.id]; p != "" {
			if l, t, b, ok := inkBox(filepath.Join(skinDir, p)); ok {
				fmt.Fprintf(&sb, "\t%sInkL = %s,\n\t%sInkT = %s,\n\t%sInkB = %s,\n", d.key, luaNum(l), d.key, luaNum(t), d.key, luaNum(b))
			}
		}
	}
	sb.WriteString("\tmania = {\n")
	for _, k := range []int{4, 7} {
		m := mania[k]
		fmt.Fprintf(&sb, "\t\t[%d] = { columnWidth = %s, hitPosition = %s, scorePosition = %s, comboPosition = %s, columnStart = %s, upsideDown = %v },\n", k,
			luaNum(num(m["columnwidth"], 30)*maniaScale), luaNum(num(m["hitposition"], 402)*maniaScale),
			luaNum(num(m["scoreposition"], 325)*maniaScale), luaNum(num(m["comboposition"], 111)*maniaScale),
			luaNum(num(m["columnstart"], 136)*maniaScale), strings.TrimSpace(m["upsidedown"]) == "1")
	}
	sb.WriteString("\t},\n\tnoteskins = {")
	for _, ns := range noteSkins {
		if ns.SkinFolder == folder && strings.HasPrefix(ns.Name, osuNoteSkinPrefix) {
			fmt.Fprintf(&sb, " %s = %s,", ns.Game, luaStr(strings.ToLower(ns.Name)))
		}
	}
	sb.WriteString(" },\n}")
	return sb.String()
}

// skinEntryVersion changes whenever skinEntry writes something new (stage art per key count, the
// skin's accent colour...), so every cached skin entry is made again.
const skinEntryVersion = "4"

// skinSignature changes whenever a skin's files change, so cached skin entries stay correct.
func skinSignature(dir string) string {
	var n, size, newest int64
	filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if info, err := d.Info(); err == nil {
			n++
			size += info.Size()
			if t := info.ModTime().UnixNano(); t > newest {
				newest = t
			}
		}
		return nil
	})
	return fmt.Sprintf("%s|%s|%d|%d|%d|%d", converterVersion, skinEntryVersion, len(ThemeElements), n, size, newest)
}

type skinCache struct {
	Skins map[string]struct {
		Sig string `json:"sig"`
		Lua string `json:"lua"`
	} `json:"skins"`
}

// buildThemeSkins describes every osu! skin for the interface, so the skin used for menus can be
// picked in VSRG Hub's options (it follows the skin selected in osu! unless you pick another).
func buildThemeSkins(root, etterna, osuDir string, noteSkins []noteSkin, collectionsLua string, keep map[string]bool) {
	themeDir := filepath.Join(root, "Themes", themeName)
	if isLink(filepath.Join(themeDir, "skin")) { // the single link older versions made
		removeLink(filepath.Join(themeDir, "skin"))
	}
	copySkinSettings(etterna, noteSkins)
	dataFile := filepath.Join(themeDir, "Scripts", "00 VSRG Hub skin.lua")
	keepAdd(keep, "Themes/"+themeName+"/Scripts/00 VSRG Hub skin.lua")
	var sb strings.Builder
	sb.WriteString("-- Written by VSRG Hub at launch from your osu! skins and the noteskins it made.\n")
	// VSRG Hub's noteskins with their column width, so gameplay can space columns like osu! does.
	sb.WriteString("TW_NOTESKINS = {\n")
	for _, ns := range noteSkins {
		fmt.Fprintf(&sb, "\t[%s] = { width = %s, game = %q, skin = %s },\n", luaStr(strings.ToLower(ns.Name)), luaNum(ns.ColWidth), ns.Game, luaStr(ns.SkinFolder))
	}
	sb.WriteString("}\n")
	// the same per game: an osu! skin's 4K and 7K noteskins share a name but not their column width
	sb.WriteString("TW_NOTESKINS_GAME = { dance = {}, kb7 = {}, beat = {} }\n")
	for _, ns := range noteSkins {
		cols := ""
		if len(ns.ColX) > 0 {
			var xs, ws []string
			for i := range ns.ColX {
				xs = append(xs, luaNum(math.Round(ns.ColX[i]*100)/100))
				ws = append(ws, luaNum(ns.ColW[i]))
			}
			cols = fmt.Sprintf(", colX = { %s }, colW = { %s }", strings.Join(xs, ", "), strings.Join(ws, ", "))
		}
		if ns.Hud != nil {
			cols += ", qv = " + ns.Hud.lua()
		}
		fmt.Fprintf(&sb, "TW_NOTESKINS_GAME[%q] = TW_NOTESKINS_GAME[%q] or {}; TW_NOTESKINS_GAME[%q][%s] = { width = %s, game = %q, skin = %s%s }\n",
			ns.Game, ns.Game, ns.Game, luaStr(strings.ToLower(ns.Name)), luaNum(ns.ColWidth), ns.Game, luaStr(ns.SkinFolder), cols)
	}
	// every noteskin per game, Etterna's own included, for the pickers
	sb.WriteString("TW_ALL_NOTESKINS = {\n")
	for _, game := range []string{"dance", "kb7"} {
		seen := map[string]bool{}
		var names []string
		add := func(n string) {
			n = strings.ToLower(n)
			if !seen[n] && n != "common" {
				seen[n] = true
				names = append(names, n)
			}
		}
		for _, ns := range noteSkins {
			if ns.Game == game {
				add(ns.Name)
			}
		}
		var own []string
		if dirs, err := os.ReadDir(filepath.Join(etterna, "NoteSkins", game)); err == nil {
			for _, d := range dirs {
				if d.IsDir() {
					own = append(own, d.Name())
				}
			}
		}
		sort.Slice(own, func(i, j int) bool { return strings.ToLower(own[i]) < strings.ToLower(own[j]) })
		for _, n := range own {
			add(n)
		}
		fmt.Fprintf(&sb, "\t%s = {", game)
		for _, n := range names {
			sb.WriteString(" " + luaStr(n) + ",")
		}
		sb.WriteString(" },\n")
	}
	sb.WriteString("}\n")

	current := ""
	if osuDir != "" {
		current = osuCurrentSkin(osuDir)
	}
	st := loadState(dataDir)
	fmt.Fprintf(&sb, "TW_OSU_SKIN = %s\nTW_OSU_CHANGED = %v\n", luaStr(current), st.OsuSkin != current)
	if st.OsuSkin != current {
		st.OsuSkin = current
		saveState(dataDir, st)
	}

	var cache skinCache
	readFileJSON(filepath.Join(root, "triwheel-skincache.json"), &cache)
	if cache.Skins == nil {
		cache.Skins = map[string]struct {
			Sig string `json:"sig"`
			Lua string `json:"lua"`
		}{}
	}
	newCache := skinCache{Skins: map[string]struct {
		Sig string `json:"sig"`
		Lua string `json:"lua"`
	}{}}
	sb.WriteString("TW_SKINS = {\n")
	n := 0
	if osuDir != "" {
		dirs, _ := os.ReadDir(filepath.Join(osuDir, "Skins"))
		used := map[string]int{}
		for _, d := range dirs {
			if !d.IsDir() {
				continue
			}
			skinDir := filepath.Join(osuDir, "Skins", d.Name())
			safe := strings.ReplaceAll(asciiName(d.Name()), " ", "_")
			used[strings.ToLower(safe)]++
			if c := used[strings.ToLower(safe)]; c > 1 {
				safe = fmt.Sprintf("%s_%d", safe, c)
			}
			rel := "Themes/" + themeName + "/skins/" + safe
			if err := ensureJunction(filepath.Join(root, filepath.FromSlash(rel)), skinDir); err != nil {
				logf("theme skin %s: %v", d.Name(), err)
				continue
			}
			keepAdd(keep, rel)
			sig := skinSignature(skinDir) + "|" + safe
			entry := ""
			if c, ok := cache.Skins[d.Name()]; ok && c.Sig == sig {
				entry = c.Lua
			} else {
				entry = skinEntry(skinDir, d.Name(), "/"+rel+"/", noteSkins)
			}
			newCache.Skins[d.Name()] = struct {
				Sig string `json:"sig"`
				Lua string `json:"lua"`
			}{sig, entry}
			fmt.Fprintf(&sb, "\t[%s] = %s,\n", luaStr(d.Name()), entry)
			n++
		}
		keepAdd(keep, "Themes/"+themeName+"/skins")
	}
	sb.WriteString("}\n")
	sb.WriteString(collectionsLua)
	if b, err := json.Marshal(newCache); err == nil {
		os.WriteFile(filepath.Join(root, "triwheel-skincache.json"), b, 0o644)
	}
	keepAdd(keep, "triwheel-skincache.json")
	os.MkdirAll(filepath.Dir(dataFile), 0o755)
	writeIfChanged(dataFile, sb.String())
	logf("theme: %d osu! skins ready for the interface; osu! is using %q", n, current)
}

func parseRGB(v string) ([3]int, bool) {
	var rgb [3]int
	parts := strings.Split(v, ",")
	if len(parts) < 3 {
		return rgb, false
	}
	for i := 0; i < 3; i++ {
		n, err := strconv.Atoi(strings.TrimSpace(parts[i]))
		if err != nil {
			return rgb, false
		}
		rgb[i] = n
	}
	return rgb, true
}

// triwheel-state.json remembers things between launches.
type twState struct {
	OsuSkin      string `json:"osuSkinForNotes"`
	EtternaTheme string `json:"etternaTheme"`
	DiscordOff   bool   `json:"discordOff"` // (the Discord presence turned off on the Options page)
	KeepOpen     bool   `json:"keepOpen"`   // (the launcher stays open while the game runs: Options page)
	NoticesOff   bool   `json:"noticesOff"` // (the ranking notices turned off: Options page)
}

func loadState(root string) twState {
	var st twState
	readFileJSON(filepath.Join(root, "triwheel-state.json"), &st)
	return st
}

func saveState(root string, st twState) {
	b, _ := json.MarshalIndent(st, "", "  ")
	os.WriteFile(filepath.Join(root, "triwheel-state.json"), b, 0o644)
}

// buildRoot makes the folder Etterna mounts over its own (ETTERNA_ADDITIONAL_ROOT_DIRS).
func buildRoot(root, etterna, osuDir, quaverDir, collectionsLua string) {
	os.MkdirAll(root, 0o755)
	keep := map[string]bool{}
	var old manifest
	readFileJSON(filepath.Join(root, "triwheel-manifest.json"), &old)
	// fonts a test build left under names Etterna mixes up with the real ones ("_vh bold" also
	// matched "_vh bold big"), which stops the game with an error
	for _, f := range []string{"VSRG Hub osu!/Fonts/_vh sans big", "VSRG Hub osu!/Fonts/_vh bold big",
		"VSRG Hub Quaver/Fonts/_twsans regular big", "VSRG Hub Quaver/Fonts/_twsans bold big", "VSRG Hub Quaver/Fonts/_twsans black big"} {
		p := filepath.Join(root, "Themes", filepath.FromSlash(f))
		os.Remove(p + ".ini")
		os.Remove(p + " [main] 16x12 (doubleres).png")
	}
	os.MkdirAll(filepath.Join(root, "Data"), 0o755)
	writeIfChanged(filepath.Join(root, "Data", "Static.ini"),
		"; Written by VSRG Hub. Only applies while Etterna is started by VSRG Hub; never saved to your Preferences.ini.\n[Options]\nTheme="+pickedTheme(root, etterna)+"\n"+
			// (Etterna's own judgement windows: the Quaver look's windows change them while it runs, never for good)
			"TimingWindowSecondsW1=0.022500\nTimingWindowSecondsW2=0.045000\nTimingWindowSecondsW3=0.090000\nTimingWindowSecondsW4=0.135000\nTimingWindowSecondsW5=0.180000\n"+strings.ReplaceAll(devPrefs, `\n`, "\n"))
	keepAdd(keep, "Data/Static.ini")
	// VSRG Hub's theme picker (Ctrl+O) inside Etterna's own themes, mounted over them, never written into them
	for _, t := range etternaThemes {
		if dirExists(filepath.Join(etterna, "Themes", t)) {
			rel := "Themes/" + t + "/BGAnimations/ScreenSystemLayer error.lua"
			os.MkdirAll(filepath.Join(root, filepath.FromSlash(filepath.Dir(rel))), 0o755)
			writeIfChanged(filepath.Join(root, filepath.FromSlash(rel)), themeSwitchLua)
			keepAdd(keep, rel)
			// pausing (loaded by the file above, so every look has it)
			prel := "Themes/" + t + "/BGAnimations/VSRG Hub pause.lua"
			writeIfChanged(filepath.Join(root, filepath.FromSlash(prel)), pauseLua)
			keepAdd(keep, prel)
			// keybinds (loaded first by the file above; the VSRG Hub looks load it from their scripts too)
			krel := "Themes/" + t + "/BGAnimations/VSRG Hub keys.lua"
			writeIfChanged(filepath.Join(root, filepath.FromSlash(krel)), keysLua)
			keepAdd(keep, krel)
			// Customize Gameplay's panel (the osu! and Quaver looks' notefield settings in these themes)
			urel := "Themes/" + t + "/BGAnimations/VSRG Hub customize.lua"
			writeIfChanged(filepath.Join(root, filepath.FromSlash(urel)), customizeLua)
			keepAdd(keep, urel)
			// your profile page (every look: the osu! and Quaver looks load it from here too)
			frel := "Themes/" + t + "/BGAnimations/VSRG Hub profile.lua"
			writeIfChanged(filepath.Join(root, filepath.FromSlash(frel)), profileLua)
			keepAdd(keep, frel)
			// a sharper copy of the osu! look's font (Ubuntu) for the profile page's big text (from the osu! look)
			for _, fn := range []string{"_vhx sans.ini", "_vhx sans [main] 16x12 (doubleres).png"} {
				src := filepath.Join(root, "Themes", themeName, "Fonts", fn)
				b, err := os.ReadFile(src)
				if err != nil {
					continue
				}
				vrel := "Themes/" + t + "/Fonts/" + fn
				os.MkdirAll(filepath.Join(root, filepath.FromSlash(filepath.Dir(vrel))), 0o755)
				writeIfChanged(filepath.Join(root, filepath.FromSlash(vrel)), string(b))
				keepAdd(keep, vrel)
			}
			// VSRG Hub's icon on the game's window in these themes too
			if b, err := os.ReadFile(filepath.Join(root, "Themes", themeName, "Graphics", "Common window icon.png")); err == nil {
				irel := "Themes/" + t + "/Graphics/Common window icon.png"
				os.MkdirAll(filepath.Join(root, filepath.FromSlash(filepath.Dir(irel))), 0o755)
				writeIfChanged(filepath.Join(root, filepath.FromSlash(irel)), string(b))
				keepAdd(keep, irel)
			}
			// your osu! collections, for the picker's song filter
			crel := "Themes/" + t + "/BGAnimations/VSRG Hub collections.lua"
			writeIfChanged(filepath.Join(root, filepath.FromSlash(crel)), "-- Written by VSRG Hub: your osu! collections.\n"+collectionsLua+"return Def.Actor {}\n")
			keepAdd(keep, crel)
		}
	}
	all, o, q := buildNoteSkins(root, osuDir, quaverDir, keep)
	logf("noteskins: %d from osu! skins, %d from Quaver skins", o, q)
	buildThemeSkins(root, etterna, osuDir, all, collectionsLua, keep)
	cleanOwned(root, old, keep)
}

// skinAccent finds a skin's main colour, for the parts of the osu! look VSRG Hub draws itself (the
// mode / mods / random / options buttons, tabs, highlights) so they match the skin instead of
// osu!'s strong pink. It looks at the skin's own coloured art (its song select buttons, cursor,
// health bar, notes and menu background), takes the most common lively hue, and tones it down a
// little so text on it stays readable.
func skinAccent(skinDir string, files skinFiles) ([3]int, bool) {
	type src struct {
		name   string
		weight float64
	}
	// the menu background is a picture with many colours: it only tips the balance
	srcs := []src{{"selection-mods", 3}, {"selection-mode", 3}, {"selection-random", 2}, {"selection-options", 2},
		{"cursor", 3}, {"scorebar-colour", 2}, {"mania-note1", 2}, {"mania-note2", 1}, {"menu-back", 1.5},
		{"button-left", 1}, {"selection-mod-nofail", 1}, {"selection-mod-hidden", 1}, {"selection-mod-doubletime", 1},
		{"pause-continue", 1}, {"menu-background", 0.5}}
	const bins = 24
	var weight [bins]float64
	var sum [bins][3]float64
	any := false
	for _, s := range srcs {
		p := files.image(s.name)
		if p == "" {
			continue
		}
		full := filepath.Join(skinDir, p)
		if tooLarge(full) {
			continue
		}
		f, err := os.Open(full)
		if err != nil {
			continue
		}
		img, _, err := image.Decode(f)
		f.Close()
		if err != nil {
			continue
		}
		b := img.Bounds()
		step := 1
		for (b.Dx()/step)*(b.Dy()/step) > 40000 {
			step++
		}
		var local [bins]float64
		var localSum [bins][3]float64
		total := 0.0
		for y := b.Min.Y; y < b.Max.Y; y += step {
			for x := b.Min.X; x < b.Max.X; x += step {
				r16, g16, b16, a16 := img.At(x, y).RGBA()
				if a16 < 0x8000 {
					continue
				}
				// un-premultiply
				r, g, bl := float64(r16)/float64(a16), float64(g16)/float64(a16), float64(b16)/float64(a16)
				mx, mn := max(r, g, bl), min(r, g, bl)
				sat := 0.0
				if mx > 0 {
					sat = (mx - mn) / mx
				}
				if sat < 0.25 || mx < 0.25 {
					continue // greys, whites and near-blacks say nothing about the colour
				}
				h := 0.0
				switch {
				case mx == r:
					h = (g - bl) / (mx - mn)
				case mx == g:
					h = 2 + (bl-r)/(mx-mn)
				default:
					h = 4 + (r-g)/(mx-mn)
				}
				h /= 6
				if h < 0 {
					h++
				}
				i := int(h*bins) % bins
				w := sat * mx
				local[i] += w
				localSum[i][0] += r * w
				localSum[i][1] += g * w
				localSum[i][2] += bl * w
				total += w
			}
		}
		if total <= 0 {
			continue
		}
		// each image counts by its weight, however big it is
		for i := range local {
			k := s.weight / total
			weight[i] += local[i] * k
			for c := 0; c < 3; c++ {
				sum[i][c] += localSum[i][c] * k
			}
		}
		any = true
	}
	if !any {
		return [3]int{}, false
	}
	best := 0
	for i := range weight {
		// neighbouring hues help each other, so a gradient isn't split between two bins
		score := weight[i] + 0.5*(weight[(i+1)%bins]+weight[(i+bins-1)%bins])
		bestScore := weight[best] + 0.5*(weight[(best+1)%bins]+weight[(best+bins-1)%bins])
		if score > bestScore {
			best = i
		}
	}
	if weight[best] <= 0 {
		return [3]int{}, false
	}
	r, g, bl := sum[best][0]/weight[best], sum[best][1]/weight[best], sum[best][2]/weight[best]
	// tone it down: at most 60% saturation, lightness between 0.42 and 0.58
	h, s, l := rgbToHSL(r, g, bl)
	s = min(s, 0.6)
	l = max(0.42, min(l, 0.58))
	r, g, bl = hslToRGB(h, s, l)
	return [3]int{int(r*255 + 0.5), int(g*255 + 0.5), int(bl*255 + 0.5)}, true
}

func rgbToHSL(r, g, b float64) (h, s, l float64) {
	mx, mn := max(r, g, b), min(r, g, b)
	l = (mx + mn) / 2
	if mx == mn {
		return 0, 0, l
	}
	d := mx - mn
	if l > 0.5 {
		s = d / (2 - mx - mn)
	} else {
		s = d / (mx + mn)
	}
	switch mx {
	case r:
		h = (g - b) / d
		if g < b {
			h += 6
		}
	case g:
		h = (b-r)/d + 2
	default:
		h = (r-g)/d + 4
	}
	return h / 6, s, l
}

func hslToRGB(h, s, l float64) (r, g, b float64) {
	if s == 0 {
		return l, l, l
	}
	var q float64
	if l < 0.5 {
		q = l * (1 + s)
	} else {
		q = l + s - l*s
	}
	p := 2*l - q
	hue := func(t float64) float64 {
		if t < 0 {
			t++
		}
		if t > 1 {
			t--
		}
		switch {
		case t < 1.0/6:
			return p + (q-p)*6*t
		case t < 0.5:
			return q
		case t < 2.0/3:
			return p + (q-p)*(2.0/3-t)*6
		}
		return p
	}
	return hue(h + 1.0/3), hue(h), hue(h - 1.0/3)
}

// copySkinSettings brings a skin's own VSRG Hub settings along: a skin maker can put the file the
// game's "Export skin settings" writes into the skin's folder, as vsrghub-4k.vhskin or
// vsrghub-7k.vhskin (or vsrghub.vhskin for both), and whoever installs the skin gets its notefield
// set up as the maker had it, the first time they play with it (Scripts/27 VSRG Hub layout.lua
// reads Save/VSRGHub/skins/auto/<noteskin>.vhskin). Save/VSRGHub/skins/ is where the game's own
// exports go.
func copySkinSettings(etterna string, noteSkins []noteSkin) {
	dir := filepath.Join(etterna, "Save", "VSRGHub", "skins", "auto")
	os.MkdirAll(dir, 0o755)
	for _, ns := range noteSkins {
		if ns.Source == "" {
			continue
		}
		keys := "4k"
		if ns.Game == "kb7" {
			keys = "7k"
		}
		dst := filepath.Join(dir, strings.ToLower(ns.Name)+".vhskin")
		var src string
		for _, name := range []string{"vsrghub-" + keys + ".vhskin", "vsrghub.vhskin"} {
			if st, err := os.Stat(filepath.Join(ns.Source, name)); err == nil && !st.IsDir() && st.Size() < 1<<20 {
				src = filepath.Join(ns.Source, name)
				break
			}
		}
		if src == "" {
			os.Remove(dst)
			continue
		}
		b, err := os.ReadFile(src)
		if err != nil || !bytes.Contains(b, []byte("VSRG Hub skin settings")) {
			continue
		}
		if old, err := os.ReadFile(dst); err == nil && bytes.Equal(old, b) {
			continue
		}
		os.WriteFile(dst, b, 0o644)
	}
}

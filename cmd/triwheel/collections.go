package main

// osu! collections (collection.db) become VSRG Hub collections: lists of the converted charts,
// so song select can show just one collection, like osu!'s "Collections" grouping.

import (
	"bufio"
	"crypto/md5"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type osuCollection struct {
	Name   string
	Hashes []string
}

func readOsuString(r *bufio.Reader) (string, error) {
	b, err := r.ReadByte()
	if err != nil {
		return "", err
	}
	if b == 0 {
		return "", nil
	}
	if b != 0x0b {
		return "", fmt.Errorf("bad string marker %x", b)
	}
	var n uint64
	var shift uint
	for {
		c, err := r.ReadByte()
		if err != nil {
			return "", err
		}
		n |= uint64(c&0x7f) << shift
		if c&0x80 == 0 {
			break
		}
		shift += 7
	}
	buf := make([]byte, n)
	if _, err := io.ReadFull(r, buf); err != nil {
		return "", err
	}
	return string(buf), nil
}

func readCollectionDB(path string) ([]osuCollection, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	r := bufio.NewReader(f)
	var version, count int32
	if err := binary.Read(r, binary.LittleEndian, &version); err != nil {
		return nil, err
	}
	if err := binary.Read(r, binary.LittleEndian, &count); err != nil {
		return nil, err
	}
	var out []osuCollection
	for i := 0; i < int(count); i++ {
		name, err := readOsuString(r)
		if err != nil {
			return out, err
		}
		var n int32
		if err := binary.Read(r, binary.LittleEndian, &n); err != nil {
			return out, err
		}
		c := osuCollection{Name: name}
		for j := 0; j < int(n); j++ {
			h, err := readOsuString(r)
			if err != nil {
				return out, err
			}
			c.Hashes = append(c.Hashes, strings.ToLower(h))
		}
		out = append(out, c)
	}
	return out, nil
}

type md5Entry struct {
	Size    int64  `json:"s"`
	ModTime int64  `json:"t"`
	MD5     string `json:"h"`
	Version string `json:"v"`
}

// buildCollections writes TW_COLLECTIONS: for each osu! collection, the library song folders and
// difficulty names of its maps that VSRG Hub converted.
func buildCollections(lib, osuDir string) string {
	var sb strings.Builder
	sb.WriteString("TW_COLLECTIONS = {\n")
	if osuDir == "" {
		return sb.String() + "}\n"
	}
	cols, err := readCollectionDB(filepath.Join(osuDir, "collection.db"))
	if err != nil && len(cols) == 0 {
		if !os.IsNotExist(err) {
			logf("osu! collections: %v", err)
		}
		return sb.String() + "}\n"
	}
	byHash := osuMD5Index(lib, osuDir)
	// library song folders made from each osu! set
	var cache cacheFile
	if b, err := os.ReadFile(filepath.Join(lib, "triwheel-cache.json")); err == nil {
		json.Unmarshal(b, &cache)
	}
	total := 0
	for _, c := range cols {
		type item struct{ dir, diff string }
		seen := map[item]bool{}
		var items []item
		for _, h := range c.Hashes {
			hit, ok := byHash[h]
			if !ok {
				continue
			}
			ce, ok := cache.Sets["osu!|"+hit.Set]
			if !ok {
				continue
			}
			for _, song := range ce.Songs {
				it := item{"osu!/" + song, hit.Version}
				if !seen[it] {
					seen[it] = true
					items = append(items, it)
				}
			}
		}
		sort.Slice(items, func(i, j int) bool { return items[i].dir < items[j].dir })
		fmt.Fprintf(&sb, "\t{ name = %s, maps = %d, charts = {", luaStr(c.Name), len(c.Hashes))
		for _, it := range items {
			fmt.Fprintf(&sb, " { %s, %s },", luaStr(strings.ToLower(it.dir)), luaStr(it.diff))
		}
		sb.WriteString(" } },\n")
		total++
	}
	logf("osu! collections: %d", total)
	return sb.String() + "}\n"
}

// osuVersionOf reads "Version:" (the difficulty name) from a .osu file.
func osuVersionOf(b []byte) string {
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Version:") {
			return strings.TrimSpace(strings.TrimPrefix(line, "Version:"))
		}
		if strings.HasPrefix(line, "[Difficulty]") {
			break
		}
	}
	return ""
}

// osuHashHit: the .osu file an osu! beatmap hash (its file's MD5, as osu! names maps) belongs to
type osuHashHit struct {
	Set, File, Version string
}

// osuMD5Index: the MD5 of every .osu file in the osu! Songs folder, cached by size and time (in
// triwheel-md5.json) so only new or edited maps are read.
func osuMD5Index(lib, osuDir string) map[string]osuHashHit {
	cachePath := filepath.Join(lib, "triwheel-md5.json")
	old := map[string]md5Entry{}
	if b, err := os.ReadFile(cachePath); err == nil {
		json.Unmarshal(b, &old)
	}
	byHash := map[string]osuHashHit{}
	fresh := map[string]md5Entry{}
	songsDir := osuSongDir(osuDir)
	sets, _ := os.ReadDir(songsDir)
	for _, set := range sets {
		if !set.IsDir() {
			continue
		}
		files, _ := os.ReadDir(filepath.Join(songsDir, set.Name()))
		for _, fe := range files {
			if fe.IsDir() || !strings.EqualFold(filepath.Ext(fe.Name()), ".osu") {
				continue
			}
			info, err := fe.Info()
			if err != nil {
				continue
			}
			key := set.Name() + "/" + fe.Name()
			e, ok := old[key]
			if !ok || e.Size != info.Size() || e.ModTime != info.ModTime().UnixNano() {
				b, err := os.ReadFile(filepath.Join(songsDir, set.Name(), fe.Name()))
				if err != nil {
					continue
				}
				sum := md5.Sum(b)
				e = md5Entry{Size: info.Size(), ModTime: info.ModTime().UnixNano(), MD5: hex.EncodeToString(sum[:]), Version: osuVersionOf(b)}
			}
			fresh[key] = e
			byHash[e.MD5] = osuHashHit{Set: set.Name(), File: fe.Name(), Version: e.Version}
		}
	}
	if b, err := json.Marshal(fresh); err == nil {
		os.WriteFile(cachePath, b, 0o644)
	}
	return byHash
}

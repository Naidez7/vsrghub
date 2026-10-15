package main

// EtternaOnline for the profile page: Etterna's Lua can't reach the internet, so the profile page
// asks VSRG Hub. It writes its requests to Save/VSRGHub/eo/req.txt ("seq|slot|kind|arg" lines, the
// newest ones); VSRG Hub, running alongside Etterna, fetches them from EtternaOnline's public API
// (no login needed) and writes each answer as a Lua table to Save/VSRGHub/eo/res-<slot>.lua, ending
// in "--end<seq>" so a half-written file is never read. Kinds:
//
//	user <name>       the player: country, rating and skillsets, world ranks
//	scores <name|page> a page of online scores (200, newest first)
//	board <page>      the global leaderboard, 50 a page
//	country <code>    the players of one country, ranked (from the whole leaderboard, kept a day)
//	clip              the clipboard's text (Ctrl+V in the login; wiped from the file 3 s later)

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

var eoAPI = "https://api.etternaonline.com/api/"

const (
	eoSlots = 24
)

type eoBridge struct {
	dir    string
	client *http.Client
	done   chan struct{}
	wg     sync.WaitGroup

	mu       sync.Mutex
	board    []eoUser // the whole global leaderboard (for the country boards)
	boardAt  time.Time
	boarding bool
}

type eoUser struct {
	Name    string             `json:"username"`
	Country string             `json:"country"`
	Overall float64            `json:"overall"`
	Skills  map[string]float64 `json:"skills"`
}

// startEO starts answering the profile page's requests; the returned function stops it.
func startEO(dataDir string) func() {
	b := &eoBridge{dir: filepath.Join(dataDir, "eo"), client: &http.Client{Timeout: 90 * time.Second}, done: make(chan struct{})}
	if err := os.MkdirAll(b.dir, 0o755); err != nil {
		logf("EtternaOnline: %v", err)
		return func() {}
	}
	// (a new game: no old requests or answers)
	os.WriteFile(filepath.Join(b.dir, "req.txt"), nil, 0o644)
	for i := 1; i <= eoSlots; i++ {
		os.WriteFile(b.slotPath(i), []byte("return nil --end0\n"), 0o644)
	}
	b.loadBoardCache()
	b.wg.Add(1)
	go b.loop()
	// (stopping doesn't wait for a download still going: the game is closing)
	return func() {
		close(b.done)
		waited := make(chan struct{})
		go func() { b.wg.Wait(); close(waited) }()
		select {
		case <-waited:
		case <-time.After(time.Second):
		}
	}
}

func (b *eoBridge) slotPath(slot int) string {
	return filepath.Join(b.dir, fmt.Sprintf("res-%02d.lua", slot))
}

func (b *eoBridge) loop() {
	defer b.wg.Done()
	last := 0
	tick := time.NewTicker(250 * time.Millisecond)
	defer tick.Stop()
	work := make(chan [4]string, 32)
	// two at a time: a long score download doesn't hold up a leaderboard page
	for w := 0; w < 2; w++ {
		b.wg.Add(1)
		go func() {
			defer b.wg.Done()
			for {
				select {
				case <-b.done:
					return
				case r := <-work:
					b.answer(r)
				}
			}
		}()
	}
	for {
		select {
		case <-b.done:
			return
		case <-tick.C:
		}
		data, err := os.ReadFile(filepath.Join(b.dir, "req.txt"))
		if err != nil {
			continue
		}
		for _, line := range strings.Split(strings.ReplaceAll(string(data), "\r", ""), "\n") {
			p := strings.SplitN(line, "|", 4)
			if len(p) != 4 {
				continue
			}
			seq, err := strconv.Atoi(p[0])
			if err != nil || seq <= last {
				continue
			}
			last = seq
			select {
			case work <- [4]string{p[0], p[1], p[2], p[3]}:
			default:
			}
		}
	}
}

func (b *eoBridge) answer(r [4]string) {
	seq, kind, arg := r[0], r[2], strings.TrimSpace(r[3])
	slot, err := strconv.Atoi(r[1])
	if err != nil || slot < 1 || slot > eoSlots {
		return
	}
	var body string
	switch kind {
	case "user":
		body, err = b.user(arg)
	case "scores":
		body, err = b.scores(arg)
	case "board":
		body, err = b.boardPage(arg)
	case "country":
		body, err = b.country(arg)
	case "clip":
		// Ctrl+V in the profile page's login: the clipboard's text (wiped from the answer file soon after)
		body = luaText(clipboardText())
	default:
		err = fmt.Errorf("unknown request")
	}
	var out string
	if err != nil {
		out = fmt.Sprintf("return { seq = %s, ok = false, err = %s } --end%s\n", seq, luaText(err.Error()), seq)
	} else {
		out = fmt.Sprintf("return { seq = %s, ok = true, data = %s } --end%s\n", seq, body, seq)
	}
	tmp := b.slotPath(slot) + ".tmp"
	if os.WriteFile(tmp, []byte(out), 0o644) == nil {
		if os.Rename(tmp, b.slotPath(slot)) != nil {
			os.WriteFile(b.slotPath(slot), []byte(out), 0o644)
			os.Remove(tmp)
		}
	}
	if kind == "clip" {
		go func() {
			time.Sleep(3 * time.Second)
			os.WriteFile(b.slotPath(slot), []byte("return nil --end0\n"), 0o644)
		}()
	}
}

// get fetches one API path into v (trying twice: EtternaOnline is slow at times)
func (b *eoBridge) get(path string, v any) error {
	err := b.get1(path, v)
	if err != nil && err.Error() != "not found" {
		time.Sleep(time.Second)
		err = b.get1(path, v)
	}
	return err
}
func (b *eoBridge) get1(path string, v any) error {
	req, err := http.NewRequest("GET", eoAPI+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "VSRG Hub/"+version)
	resp, err := b.client.Do(req)
	if err != nil {
		return fmt.Errorf("EtternaOnline can't be reached")
	}
	defer resp.Body.Close()
	if resp.StatusCode == 404 {
		return fmt.Errorf("not found")
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("EtternaOnline answered %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, 64<<20))
	if err != nil {
		return fmt.Errorf("EtternaOnline took too long to answer")
	}
	return json.Unmarshal(data, v)
}

// numbers come as numbers or as strings
func num(v any) float64 {
	switch x := v.(type) {
	case float64:
		return x
	case string:
		f, _ := strconv.ParseFloat(strings.TrimSpace(x), 64)
		return f
	case bool:
		if x {
			return 1
		}
	}
	return 0
}
func str(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	if v == nil {
		return ""
	}
	return fmt.Sprint(v)
}

var eoSkills = []string{"stream", "jumpstream", "handstream", "stamina", "jacks", "chordjacks", "technical"}

// luaText: a Lua string with anything odd escaped
func luaText(s string) string {
	var sb strings.Builder
	sb.WriteByte('"')
	for _, r := range s {
		switch {
		case r == '\\':
			sb.WriteString(`\\`)
		case r == '"':
			sb.WriteString(`\"`)
		case r < 32 || r == 127:
			fmt.Fprintf(&sb, `\%d`, r)
		default:
			sb.WriteRune(r)
		}
	}
	sb.WriteByte('"')
	return sb.String()
}
func luaF(f float64) string { return strconv.FormatFloat(f, 'f', 3, 64) }

func skillsLua(m map[string]any) string {
	var sb strings.Builder
	sb.WriteString("{")
	for i, k := range eoSkills {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString(luaF(num(m[k])))
	}
	sb.WriteString("}")
	return sb.String()
}

func (b *eoBridge) user(name string) (string, error) {
	var r struct {
		Data map[string]any `json:"data"`
	}
	if err := b.get("users/"+url.PathEscape(name), &r); err != nil {
		return "", err
	}
	d := r.Data
	if d == nil {
		return "", fmt.Errorf("not found")
	}
	ranks := "{"
	if m, ok := d["skillset_ranks"].(map[string]any); ok {
		for i, k := range eoSkills {
			if i > 0 {
				ranks += ","
			}
			ranks += strconv.Itoa(int(num(m[k])))
		}
	}
	ranks += "}"
	country := str(d["country"])
	crank, ctotal := b.countryRank(str(d["username"]), country)
	return fmt.Sprintf("{ name = %s, country = %s, overall = %s, rank = %d, skills = %s, ranks = %s, countryRank = %d, countryTotal = %d, since = %s, bio = %s }",
		luaText(str(d["username"])), luaText(country), luaF(num(d["overall"])), int(num(d["rank"])), skillsLua(d), ranks,
		crank, ctotal, luaText(str(d["created_at"])), luaText(str(d["bio"]))), nil
}

// one page (of 200, newest first) of a player's online scores: arg "name|page"
func (b *eoBridge) scores(arg string) (string, error) {
	name, page := arg, 1
	if i := strings.LastIndex(arg, "|"); i >= 0 {
		name = arg[:i]
		if p, err := strconv.Atoi(arg[i+1:]); err == nil && p > 0 {
			page = p
		}
	}
	var r struct {
		Data []map[string]any `json:"data"`
		Meta struct {
			LastPage int `json:"last_page"`
			Total    int `json:"total"`
		} `json:"meta"`
	}
	if err := b.get(fmt.Sprintf("users/%s/scores?page=%d&limit=200&sort=-datetime", url.PathEscape(name), page), &r); err != nil {
		return "", err
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "{ page = %d, pages = %d, total = %d, list = {", page, max(1, r.Meta.LastPage), r.Meta.Total)
	for _, s := range r.Data {
		song, _ := s["song"].(map[string]any)
		chart, _ := s["chart"].(map[string]any)
		if song == nil {
			song = map[string]any{}
		}
		if chart == nil {
			chart = map[string]any{}
		}
		valid := s["valid"] == true
		fmt.Fprintf(&sb, "\n{ ck = %s, title = %s, artist = %s, diff = %s, keys = %d, msd = %s, rate = %s, wife = %s, ssr = %s, s = %s, date = %s, grade = %s, valid = %v, top = %v, judge = %s, combo = %d, j = {%d,%d,%d,%d,%d,%d} },",
			luaText(str(chart["key"])), luaText(str(song["name"])), luaText(str(song["artist"])), luaText(str(chart["difficulty"])),
			int(num(chart["keys"])), luaF(num(chart["overall"])), luaF(num(s["rate"])), luaF(num(s["wife"])), luaF(num(s["overall"])),
			skillsLua(s), luaText(str(s["datetime"])), luaText(str(s["grade"])), valid, num(s["top_score"]) == 1, luaText(str(s["judge"])),
			int(num(s["combo"])), int(num(s["marvelous"])), int(num(s["perfect"])), int(num(s["great"])), int(num(s["good"])),
			int(num(s["bad"])), int(num(s["miss"])))
	}
	sb.WriteString("\n} }")
	return sb.String(), nil
}

func usersLua(list []eoUser, from int) string {
	var sb strings.Builder
	sb.WriteString("{")
	for i, u := range list {
		sk := map[string]any{}
		for k, v := range u.Skills {
			sk[k] = v
		}
		fmt.Fprintf(&sb, "\n{ rank = %d, name = %s, country = %s, overall = %s, skills = %s },", from+i, luaText(u.Name), luaText(u.Country), luaF(u.Overall), skillsLua(sk))
	}
	sb.WriteString("\n}")
	return sb.String()
}

func toUser(d map[string]any) eoUser {
	u := eoUser{Name: str(d["username"]), Country: str(d["country"]), Overall: num(d["overall"]), Skills: map[string]float64{}}
	for _, k := range eoSkills {
		u.Skills[k] = num(d[k])
	}
	return u
}

func (b *eoBridge) boardPage(arg string) (string, error) {
	page, _ := strconv.Atoi(arg)
	if page < 1 {
		page = 1
	}
	var r struct {
		Data []map[string]any `json:"data"`
		Meta struct {
			Total    int `json:"total"`
			LastPage int `json:"last_page"`
		} `json:"meta"`
	}
	if err := b.get(fmt.Sprintf("leaderboards/global?page=%d&limit=50", page), &r); err != nil {
		return "", err
	}
	list := make([]eoUser, 0, len(r.Data))
	for _, d := range r.Data {
		list = append(list, toUser(d))
	}
	return fmt.Sprintf("{ page = %d, pages = %d, total = %d, users = %s }", page, r.Meta.LastPage, r.Meta.Total, usersLua(list, (page-1)*50+1)), nil
}

// the whole leaderboard, for the country boards (EtternaOnline has no country filter), kept a day
func (b *eoBridge) wholeBoard() ([]eoUser, error) {
	b.mu.Lock()
	if b.board != nil && time.Since(b.boardAt) < 24*time.Hour {
		list := b.board
		b.mu.Unlock()
		return list, nil
	}
	b.mu.Unlock()
	var all []eoUser
	for page := 1; page <= 200; page++ {
		var r struct {
			Data []map[string]any `json:"data"`
			Meta struct {
				LastPage int `json:"last_page"`
			} `json:"meta"`
		}
		if err := b.get(fmt.Sprintf("leaderboards/global?page=%d&limit=500", page), &r); err != nil {
			if all == nil {
				return nil, err
			}
			break
		}
		for _, d := range r.Data {
			all = append(all, toUser(d))
		}
		if page >= r.Meta.LastPage || len(r.Data) == 0 {
			break
		}
	}
	sort.SliceStable(all, func(i, j int) bool { return all[i].Overall > all[j].Overall })
	b.mu.Lock()
	b.board, b.boardAt = all, time.Now()
	b.mu.Unlock()
	b.saveBoardCache()
	return all, nil
}

func (b *eoBridge) loadBoardCache() {
	var c struct {
		At    time.Time `json:"at"`
		Users []eoUser  `json:"users"`
	}
	if _, err := readFileJSON(filepath.Join(b.dir, "board-cache.json"), &c); err == nil && len(c.Users) > 0 {
		b.board, b.boardAt = c.Users, c.At
	}
}
func (b *eoBridge) saveBoardCache() {
	b.mu.Lock()
	c := struct {
		At    time.Time `json:"at"`
		Users []eoUser  `json:"users"`
	}{b.boardAt, b.board}
	data, err := json.Marshal(c)
	b.mu.Unlock()
	if err == nil {
		os.WriteFile(filepath.Join(b.dir, "board-cache.json"), data, 0o644)
	}
}

// a player's place in their country, from the kept leaderboard (0 when it isn't known yet; the
// leaderboard is fetched in the background then)
func (b *eoBridge) countryRank(name, country string) (int, int) {
	b.mu.Lock()
	list, at, busy := b.board, b.boardAt, b.boarding
	if (list == nil || time.Since(at) > 24*time.Hour) && !busy {
		b.boarding = true
		go func() {
			b.wholeBoard()
			b.mu.Lock()
			b.boarding = false
			b.mu.Unlock()
		}()
	}
	b.mu.Unlock()
	rank, total := 0, 0
	for _, u := range list {
		if strings.EqualFold(u.Country, country) {
			total++
			if strings.EqualFold(u.Name, name) {
				rank = total
			}
		}
	}
	return rank, total
}

func (b *eoBridge) country(code string) (string, error) {
	all, err := b.wholeBoard()
	if err != nil {
		return "", err
	}
	var list []eoUser
	for _, u := range all {
		if strings.EqualFold(u.Country, code) {
			list = append(list, u)
			if len(list) >= 1000 {
				break
			}
		}
	}
	return fmt.Sprintf("{ country = %s, total = %d, users = %s }", luaText(strings.ToUpper(code)), len(list), usersLua(list, 1)), nil
}

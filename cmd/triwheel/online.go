package main

// VSRG Hub online: VSRG Hub accounts (e-mail and password), your scores sent to the online
// rankings, and the rankings read back, for the launcher and the game.
//
// The server is a Supabase project (server/supabase/schema.sql): its sign-in service for the
// accounts and its database, reached over HTTPS with the project's publishable key (made to be in
// programs: what anyone may do with it is set by the database's own rules and functions).
//
// The game talks to this program through files in Etterna's Save/VSRGHub/online folder, as Etterna's
// theme can't reach the internet itself:
//   outbox/<score key>.json   a score the theme wrote on the results screen, sent when signed in
//   want.txt                  the chart whose online ranking the song select wants
//   board.txt                 that ranking, written here
//   me.txt                    who is signed in and their ratings, for the theme

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
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

const (
	onlineURL = "https://ekojitajoifsjdrrjzsv.supabase.co"
	onlineKey = "sb_publishable_yDIFMoghR6MJl7IRlkq6bw_xHHrbpH9"
)

var onlineClient = &http.Client{Timeout: 15 * time.Second}

// wantServerVersion: the server/supabase/v2.sql this program expects (its schema_version)
const wantServerVersion = 19

// onlineServerVersion: the version of v2.sql the server has run (0 when it never has, -1 offline)
func onlineServerVersion() int {
	var v int
	if err := onlineCall("POST", "/rest/v1/rpc/server_version", map[string]any{}, "", &v); err != nil {
		if err == errOffline {
			return -1
		}
		return 0
	}
	return v
}

// the signed-in account, kept (encrypted for this Windows user) in the launcher's folder
type onlineSession struct {
	Access   string `json:"access"`
	Refresh  string `json:"refresh"`
	Expires  int64  `json:"expires"`
	UserID   string `json:"user"`
	Email    string `json:"email"`
	Username string `json:"username"`
}

var (
	sessionMu sync.Mutex
	session   *onlineSession
	sessLoad  bool
)

func sessionPath() string { return filepath.Join(launcherDir(), "account.dat") }

func loadSession() *onlineSession {
	sessionMu.Lock()
	defer sessionMu.Unlock()
	if sessLoad {
		return session
	}
	sessLoad = true
	b, err := os.ReadFile(sessionPath())
	if err != nil {
		return nil
	}
	if p, err := unprotectData(b); err == nil {
		var s onlineSession
		if json.Unmarshal(p, &s) == nil && s.Refresh != "" {
			session = &s
		}
	}
	return session
}

func saveSession(s *onlineSession) {
	sessionMu.Lock()
	session, sessLoad = s, true
	sessionMu.Unlock()
	if s == nil {
		os.Remove(sessionPath())
		return
	}
	b, _ := json.Marshal(s)
	if p, err := protectData(b); err == nil {
		os.WriteFile(sessionPath(), p, 0o600)
	}
}

// a call to the server; the error is the server's own message when it gives one
func onlineCall(method, path string, body any, token string, out any) error {
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, onlineURL+path, rd)
	if err != nil {
		return err
	}
	req.Header.Set("apikey", onlineKey)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := onlineClient.Do(req)
	if err != nil {
		return errOffline
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if resp.StatusCode >= 300 {
		var e struct {
			Msg     string `json:"msg"`
			Message string `json:"message"`
			Error   string `json:"error_description"`
			Code    string `json:"error_code"`
		}
		json.Unmarshal(data, &e)
		m := e.Message
		if m == "" {
			m = e.Msg
		}
		if m == "" {
			m = e.Error
		}
		if m == "" {
			m = resp.Status
		}
		return &onlineError{status: resp.StatusCode, msg: m, code: e.Code}
	}
	if out != nil && len(data) > 0 {
		return json.Unmarshal(data, out)
	}
	return nil
}

var errOffline = errors.New("VSRG Hub's server can't be reached (no internet?)")

type onlineError struct {
	status int
	msg    string
	code   string
}

func (e *onlineError) Error() string { return friendlyOnline(e.msg) }

// the server's messages, said plainly
func friendlyOnline(m string) string {
	l := strings.ToLower(m)
	switch {
	case strings.Contains(l, "invalid login credentials"):
		return "Wrong e-mail or password."
	case strings.Contains(l, "email not confirmed"):
		return "Confirm your e-mail first: open the link in the mail we sent you."
	case strings.Contains(l, "already registered"), strings.Contains(l, "already been registered"):
		return "There's already an account with that e-mail: sign in instead."
	case strings.Contains(l, "password should be"), strings.Contains(l, "weak password"):
		return "The password is too short: use at least 6 characters."
	case strings.Contains(l, "email rate limit"), strings.Contains(l, "over_email_send_rate_limit"):
		return "VSRG Hub can't send more e-mails right now (too many accounts made in the last hour): try again in an hour."
	case strings.Contains(l, "rate limit"), strings.Contains(l, "too many"):
		return "Too many tries for now: wait a few minutes and try again."
	case strings.Contains(l, "unable to validate email"), strings.Contains(l, "invalid format"):
		return "That e-mail address doesn't look right."
	case strings.Contains(l, "that name is taken"):
		return "That player name is taken."
	case strings.Contains(l, "username_check"), strings.Contains(l, "profiles_username"):
		return "Player names are 3 to 20 letters, digits, spaces or _ - . [ ]"
	}
	return m
}

type authAnswer struct {
	Access  string `json:"access_token"`
	Refresh string `json:"refresh_token"`
	Expires int64  `json:"expires_in"`
	User    struct {
		ID    string `json:"id"`
		Email string `json:"email"`
	} `json:"user"`
	// (sign-up without a session: the e-mail has to be confirmed first)
	ID string `json:"id"`
}

func (a authAnswer) session(username string) *onlineSession {
	return &onlineSession{Access: a.Access, Refresh: a.Refresh, Expires: time.Now().Unix() + a.Expires,
		UserID: a.User.ID, Email: a.User.Email, Username: username}
}

// onlineSignUp makes an account; confirm is true when the e-mail has to be confirmed before signing in
func onlineSignUp(email, password string) (confirm bool, err error) {
	var a authAnswer
	if err := onlineCall("POST", "/auth/v1/signup", map[string]string{"email": email, "password": password}, "", &a); err != nil {
		return false, err
	}
	if a.Access == "" {
		return true, nil
	}
	s := a.session("")
	s.Username = fetchUsername(s)
	saveSession(s)
	return false, nil
}

func onlineSignIn(email, password string) error {
	var a authAnswer
	if err := onlineCall("POST", "/auth/v1/token?grant_type=password", map[string]string{"email": email, "password": password}, "", &a); err != nil {
		return err
	}
	s := a.session("")
	s.Username = fetchUsername(s)
	saveSession(s)
	return nil
}

func onlineSignOut() {
	if s := loadSession(); s != nil {
		onlineCall("POST", "/auth/v1/logout", nil, s.Access, nil)
	}
	saveSession(nil)
}

// a mail with a link to set a new password, on VSRG Hub's page (docs/reset.html on GitHub Pages)
const resetPage = "https://naidez7.github.io/vsrghub/reset.html"

func onlineResetPassword(email string) error {
	return onlineCall("POST", "/auth/v1/recover?redirect_to="+url.QueryEscape(resetPage), map[string]string{"email": email}, "", nil)
}

// whether the signed-in player is one of VSRG Hub's admins
func onlineIsAdmin(s *onlineSession) bool {
	var rows []struct {
		Admin bool `json:"is_admin"`
	}
	onlineCall("GET", "/rest/v1/profiles?select=is_admin&id=eq."+url.QueryEscape(s.UserID), nil, s.Access, &rows)
	return len(rows) > 0 && rows[0].Admin
}

// admins: a score off the rankings (or back), a player banned (or not), the scores worth a look
func onlineAdmin(fn string, args map[string]any, out any) error {
	s, err := onlineToken()
	if err != nil {
		return err
	}
	return onlineCall("POST", "/rest/v1/rpc/"+fn, args, s.Access, out)
}

// the signed-in session with a fresh access token (it lasts an hour; the refresh token renews it)
func onlineToken() (*onlineSession, error) {
	s := loadSession()
	if s == nil {
		return nil, errors.New("not signed in")
	}
	if time.Now().Unix() < s.Expires-120 {
		return s, nil
	}
	var a authAnswer
	err := onlineCall("POST", "/auth/v1/token?grant_type=refresh_token", map[string]string{"refresh_token": s.Refresh}, "", &a)
	if err != nil {
		var oe *onlineError
		if errors.As(err, &oe) && oe.status >= 400 && oe.status < 500 {
			// (signed out elsewhere, or the account is gone)
			saveSession(nil)
		}
		return nil, err
	}
	ns := a.session(s.Username)
	if ns.UserID == "" {
		ns.UserID, ns.Email = s.UserID, s.Email
	}
	saveSession(ns)
	return ns, nil
}

func fetchUsername(s *onlineSession) string {
	var rows []struct {
		Username string `json:"username"`
	}
	if onlineCall("GET", "/rest/v1/profiles?select=username&id=eq."+url.QueryEscape(s.UserID), nil, s.Access, &rows) == nil && len(rows) > 0 {
		return rows[0].Username
	}
	return ""
}

// the player name, once, after signing up
func onlineCreateProfile(name string) error {
	s, err := onlineToken()
	if err != nil {
		return err
	}
	var p struct {
		Username string `json:"username"`
	}
	if err := onlineCall("POST", "/rest/v1/rpc/create_profile", map[string]string{"name": strings.TrimSpace(name)}, s.Access, &p); err != nil {
		return err
	}
	s.Username = p.Username
	saveSession(s)
	return nil
}

type playerRating struct {
	Keys       int     `json:"keys"`
	Overall    float64 `json:"overall"`
	Stream     float64 `json:"stream"`
	Jumpstream float64 `json:"jumpstream"`
	Handstream float64 `json:"handstream"`
	Stamina    float64 `json:"stamina"`
	Jackspeed  float64 `json:"jackspeed"`
	Chordjack  float64 `json:"chordjack"`
	Technical  float64 `json:"technical"`
	Plays      int     `json:"plays"`
}

func onlineMyRatings(s *onlineSession) []playerRating {
	var rows []playerRating
	onlineCall("GET", "/rest/v1/player_ratings?select=*&user_id=eq."+url.QueryEscape(s.UserID), nil, s.Access, &rows)
	return rows
}

type rankingRow struct {
	Place     int     `json:"place"`
	Username  string  `json:"username"`
	UserID    string  `json:"user_id"`
	Rating    float64 `json:"rating"`
	Overall   float64 `json:"overall"`
	Plays     int     `json:"plays"`
	Avatar    int     `json:"avatar"`
	AvatarExt string  `json:"avatar_ext"`
	Picture   string  `json:"picture"`
}

func onlineRankings(keys int, skill string, rows, skip int) ([]rankingRow, error) {
	var out []rankingRow
	err := onlineCall("POST", "/rest/v1/rpc/rankings", map[string]any{"k": keys, "skill": skill, "max_rows": rows, "skip": skip}, "", &out)
	for i := range out {
		out[i].Picture = avatarURL(out[i].UserID, out[i].Avatar, out[i].AvatarExt)
	}
	return out, err
}

// onlineRankingsMonth: this month's ranking (the server's rankings_month)
func onlineRankingsMonth(keys int) ([]rankingRow, error) {
	var out []rankingRow
	err := onlineCall("POST", "/rest/v1/rpc/rankings_month", map[string]any{"k": keys, "max_rows": 100}, "", &out)
	for i := range out {
		out[i].Picture = avatarURL(out[i].UserID, out[i].Avatar, out[i].AvatarExt)
	}
	return out, err
}

type boardRow struct {
	Place      int     `json:"place"`
	Username   string  `json:"username"`
	UserID     string  `json:"user_id"`
	Wife       float64 `json:"wife"`
	Rate       float64 `json:"rate"`
	SSROverall float64 `json:"ssr_overall"`
	Marvelous  int     `json:"marvelous"`
	Perfect    int     `json:"perfect"`
	Great      int     `json:"great"`
	Good       int     `json:"good"`
	Bad        int     `json:"bad"`
	Miss       int     `json:"miss"`
	MaxCombo   int     `json:"max_combo"`
	Modifiers  string  `json:"modifiers"`
	PlayedAt   string  `json:"played_at"`
	Source     string  `json:"source"`
	ScoreID    int64   `json:"score_id"`
}

func onlineChartBoard(chart string) ([]boardRow, error) {
	var out []boardRow
	err := onlineCall("POST", "/rest/v1/rpc/chart_leaderboard", map[string]any{"chart": chart, "max_rows": 50}, "", &out)
	return out, err
}

// ---------------------------------------------------------------------------------------------
// the files the game and this program share

func onlineDir(data string) string { return filepath.Join(data, "online") }

// sendOutbox sends the scores the game left in the outbox (when signed in), many at a time; sent
// ones are moved to sent/, ones the server refuses to refused/ with the reason beside them. For
// each, results/<score key>.txt says what it did to your rating and place (the results screen shows
// it): "ok<TAB>keys<TAB>old rating<TAB>new rating<TAB>old place<TAB>new place" or "refused<TAB>why".
var sendMu sync.Mutex

func sendOutbox(data string) {
	sendMu.Lock()
	defer sendMu.Unlock()
	dir := filepath.Join(onlineDir(data), "outbox")
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) == 0 {
		return
	}
	s, err := onlineToken()
	if err != nil || s.Username == "" {
		why := "no player name yet"
		if err != nil {
			why = err.Error()
		}
		noteOutbox(fmt.Sprintf("%d score(s) waiting: %s", len(entries), why))
		return
	}
	before := ratingsAndPlaces(s)
	keysOf := map[string]int{}
	chartOf := map[string]string{}
	sentAny := false
	// (batches of up to 100 scores or about 3 MB: replays make some big)
	for len(entries) > 0 {
		var batch []json.RawMessage
		var names []string
		size := 0
		for len(entries) > 0 && len(batch) < batchMax && size < 3<<20 {
			e := entries[0]
			entries = entries[1:]
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
				continue
			}
			p := filepath.Join(dir, e.Name())
			b, err := os.ReadFile(p)
			if err != nil {
				continue
			}
			var head struct {
				Keys  int    `json:"keys"`
				Chart string `json:"chart_key"`
			}
			if json.Unmarshal(b, &head) != nil {
				os.Remove(p)
				continue
			}
			keysOf[strings.TrimSuffix(e.Name(), ".json")] = head.Keys
			chartOf[strings.TrimSuffix(e.Name(), ".json")] = head.Chart
			batch = append(batch, json.RawMessage(b))
			names = append(names, e.Name())
			size += len(b)
		}
		if len(batch) == 0 {
			break
		}
		var res struct {
			Kept    int `json:"kept"`
			Refused []struct {
				Key   string `json:"score_key"`
				Error string `json:"error"`
			} `json:"refused"`
		}
		err := onlineCall("POST", "/rest/v1/rpc/submit_scores", map[string]any{"list": batch}, s.Access, &res)
		if oe := (*onlineError)(nil); err != nil && errors.As(err, &oe) && (oe.code == "PGRST202" || oe.status == 404) {
			// a server without the batch call yet (v2.sql not run): one score at a time
			err = nil
			res.Kept, res.Refused = 0, nil
			for i, b := range batch {
				e := onlineCall("POST", "/rest/v1/rpc/submit_score", map[string]any{"s": b}, s.Access, nil)
				var se *onlineError
				switch {
				case e == nil:
					res.Kept++
				case errors.As(e, &se) && se.status >= 400 && se.status < 500 && se.status != 401 && se.status != 404:
					res.Refused = append(res.Refused, struct {
						Key   string `json:"score_key"`
						Error string `json:"error"`
					}{strings.TrimSuffix(names[i], ".json"), se.msg})
				default:
					err = e
				}
				if err != nil {
					// keep the ones not yet tried waiting
					names = names[:i]
					break
				}
			}
			if err != nil && len(names) == 0 {
				noteOutbox("waiting: " + err.Error())
				return
			}
			err = nil
		}
		if err == errOffline {
			noteOutbox("waiting: " + err.Error())
			return
		}
		var oe *onlineError
		if err != nil && errors.As(err, &oe) && oe.status == 401 {
			noteOutbox("waiting: the sign-in needs renewing")
			return // (the token: renewed on the next round)
		}
		if err != nil {
			// (the server gave up on a batch this big: smaller ones from here on)
			if strings.Contains(strings.ToLower(err.Error()), "timeout") && batchMax > 10 {
				batchMax = max(10, batchMax/2)
				logf("online: the server timed out on a batch: sending %d at a time", batchMax)
			}
			noteOutbox("waiting: " + err.Error())
			return
		}
		refused := map[string]string{}
		for _, r := range res.Refused {
			refused[r.Key] = friendlyOnline(r.Error)
		}
		for _, n := range names {
			key := strings.TrimSuffix(n, ".json")
			sub := "sent"
			if why, bad := refused[key]; bad {
				sub = "refused"
				logf("online: score %s refused: %s", key, why)
				writeOnline(data, "results", key+".txt", "refused\t"+why+"\n")
				writeOnline(data, "refused", key+".txt", why+"\n")
			} else {
				sentAny = true
			}
			os.MkdirAll(filepath.Join(onlineDir(data), sub), 0o755)
			os.Rename(filepath.Join(dir, n), filepath.Join(onlineDir(data), sub, n))
		}
		logf("online: %d score(s) sent, %d refused", res.Kept, len(res.Refused))
		lastOutboxNote = ""
	}
	if !sentAny {
		return
	}
	after := ratingsAndPlaces(s)
	for key, k := range keysOf {
		if _, err := os.Stat(filepath.Join(onlineDir(data), "sent", key+".json")); err != nil {
			continue
		}
		if _, err := os.Stat(filepath.Join(onlineDir(data), "results", key+".txt")); err == nil {
			continue
		}
		b, a := before[k], after[k]
		// (and where this play put you on the chart: a seventh field, 0 when not on its top)
		chartPlace := 0
		if len(keysOf) <= 5 { // (not for a backfill of thousands)
			if rows, err := onlineChart(chartOf[key], 0); err == nil {
				for _, r := range rows {
					if r.UserID == s.UserID {
						chartPlace = r.Place
						break
					}
				}
			}
		}
		writeOnline(data, "results", key+".txt", fmt.Sprintf("ok\t%d\t%.2f\t%.2f\t%d\t%d\t%d\n", k, b.rating, a.rating, b.place, a.place, chartPlace))
	}
	writeMeWith(data, s, after)
}

type ratingPlace struct {
	rating float64
	place  int
}

// your 4K and 7K ratings and places
func ratingsAndPlaces(s *onlineSession) map[int]ratingPlace {
	out := map[int]ratingPlace{}
	for _, r := range onlineMyRatings(s) {
		if r.Plays == 0 {
			continue
		}
		var place int
		onlineCall("POST", "/rest/v1/rpc/player_place", map[string]any{"player": s.UserID, "k": r.Keys}, "", &place)
		out[r.Keys] = ratingPlace{r.Overall, place}
	}
	return out
}

func writeOnline(data, sub, name, text string) {
	d := filepath.Join(onlineDir(data), sub)
	os.MkdirAll(d, 0o755)
	os.WriteFile(filepath.Join(d, name), []byte(text), 0o644)
}

// batchMax: scores per call to the server (halved when the server times out on a batch)
var batchMax = 50

// noteOutbox logs why scores are waiting (once per reason, not every few seconds)
var lastOutboxNote string

func noteOutbox(msg string) {
	if msg != lastOutboxNote {
		lastOutboxNote = msg
		logf("online: %s", msg)
	}
}

// outboxCount: the scores waiting to be sent
func outboxCount(data string) int {
	entries, _ := os.ReadDir(filepath.Join(onlineDir(data), "outbox"))
	n := 0
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".json") {
			n++
		}
	}
	return n
}

// me.txt: "name<TAB>4K rating<TAB>7K rating<TAB>4K place<TAB>7K place", or nothing when signed out
func writeMe(data string) {
	s, err := onlineToken()
	if err != nil || s.Username == "" {
		os.Remove(filepath.Join(onlineDir(data), "me.txt"))
		return
	}
	writeMeWith(data, s, ratingsAndPlaces(s))
}

func writeMeWith(data string, s *onlineSession, rp map[int]ratingPlace) {
	os.MkdirAll(onlineDir(data), 0o755)
	os.WriteFile(filepath.Join(onlineDir(data), "me.txt"), []byte(fmt.Sprintf("%s\t%.2f\t%.2f\t%d\t%d\n",
		s.Username, rp[4].rating, rp[7].rating, rp[4].place, rp[7].place)), 0o644)
}

// answerBoard writes board.txt for the chart in want.txt: a first line "chart<TAB>status" (ok,
// empty, offline), then a line per score: place, name, wife, rate, ssr, marv, perf, great, good, bad,
// miss, max combo, played at, modifiers, source, score id (tab-separated)
func answerBoard(data, chart string) {
	rows, err := onlineChartBoard(chart)
	status := "ok"
	if err != nil {
		status = "offline"
	} else if len(rows) == 0 {
		status = "empty"
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "%s\t%s\n", chart, status)
	clean := func(s string) string { return strings.NewReplacer("\t", " ", "\n", " ", "\r", " ").Replace(s) }
	for _, r := range rows {
		fmt.Fprintf(&sb, "%d\t%s\t%.4f\t%.2f\t%.2f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%d\n", r.Place, clean(r.Username), r.Wife, r.Rate,
			r.SSROverall, r.Marvelous, r.Perfect, r.Great, r.Good, r.Bad, r.Miss, r.MaxCombo, clean(r.PlayedAt), clean(r.Modifiers), r.Source, r.ScoreID)
	}
	tmp := filepath.Join(onlineDir(data), "board.tmp")
	os.WriteFile(tmp, []byte(sb.String()), 0o644)
	os.Rename(tmp, filepath.Join(onlineDir(data), "board.txt"))
}

// answerDetail writes detail/<id>.txt for one score: "id<TAB>status" (ok, offline, none), then a
// line with the eight skillset ratings, msd, holds ok, holds let go, mines hit, song title, chart
// name, keys, source, played at, modifiers (tab-separated), then the replay's offsets (ms, commas).
func answerDetail(data, id string) {
	type row struct {
		Overall    float64 `json:"ssr_overall"`
		Stream     float64 `json:"ssr_stream"`
		Jumpstream float64 `json:"ssr_jumpstream"`
		Handstream float64 `json:"ssr_handstream"`
		Stamina    float64 `json:"ssr_stamina"`
		Jackspeed  float64 `json:"ssr_jackspeed"`
		Chordjack  float64 `json:"ssr_chordjack"`
		Technical  float64 `json:"ssr_technical"`
		MSD        float64 `json:"msd"`
		HoldsOK    int     `json:"holds_ok"`
		HoldsNG    int     `json:"holds_ng"`
		Mines      int     `json:"mines_hit"`
		Title      string  `json:"song_title"`
		ChartName  string  `json:"chart_name"`
		Keys       int     `json:"keys"`
		Source     string  `json:"source"`
		PlayedAt   string  `json:"played_at"`
		Modifiers  string  `json:"modifiers"`
	}
	clean := func(s string) string { return strings.NewReplacer("\t", " ", "\n", " ", "\r", " ").Replace(s) }
	var rows []row
	status := "ok"
	err := onlineCall("GET", "/rest/v1/scores?id=eq."+url.PathEscape(id)+"&select=ssr_overall,ssr_stream,ssr_jumpstream,ssr_handstream,ssr_stamina,ssr_jackspeed,ssr_chordjack,ssr_technical,msd,holds_ok,holds_ng,mines_hit,song_title,chart_name,keys,source,played_at,modifiers", nil, "", &rows)
	if err != nil {
		status = "offline"
	} else if len(rows) == 0 {
		status = "none"
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "%s\t%s\n", id, status)
	if status == "ok" {
		r := rows[0]
		fmt.Fprintf(&sb, "%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t%d\t%d\t%s\t%s\t%d\t%s\t%s\t%s\n",
			r.Overall, r.Stream, r.Jumpstream, r.Handstream, r.Stamina, r.Jackspeed, r.Chordjack, r.Technical, r.MSD,
			r.HoldsOK, r.HoldsNG, r.Mines, clean(r.Title), clean(r.ChartName), r.Keys, r.Source, clean(r.PlayedAt), clean(r.Modifiers))
		var reps []struct {
			Offsets []float64 `json:"offsets"`
		}
		if onlineCall("GET", "/rest/v1/replays?score_id=eq."+url.PathEscape(id)+"&select=offsets", nil, "", &reps) == nil && len(reps) > 0 {
			parts := make([]string, len(reps[0].Offsets))
			for i, o := range reps[0].Offsets {
				parts[i] = strconv.FormatFloat(o, 'f', 1, 64)
			}
			sb.WriteString(strings.Join(parts, ","))
		}
		sb.WriteByte('\n')
	}
	os.MkdirAll(filepath.Join(onlineDir(data), "detail"), 0o755)
	tmp := filepath.Join(onlineDir(data), "detail", id+".tmp")
	os.WriteFile(tmp, []byte(sb.String()), 0o644)
	os.Rename(tmp, filepath.Join(onlineDir(data), "detail", id+".txt"))
}

// startOnlineService runs while the game is up: sends new scores and answers the song select's
// ranking requests. The returned function stops it.
func startOnlineService(data string) func() {
	if data == "" {
		return func() {}
	}
	dir := onlineDir(data)
	os.MkdirAll(filepath.Join(dir, "outbox"), 0o755)
	os.Remove(filepath.Join(dir, "board.txt"))
	os.Remove(filepath.Join(dir, "want.txt"))
	os.Remove(filepath.Join(dir, "wantdetail.txt"))
	os.RemoveAll(filepath.Join(dir, "detail"))
	go func() {
		if s, err := onlineToken(); err != nil {
			logf("online: not signed in (%v): plays wait in the outbox", err)
		} else if s.Username == "" {
			logf("online: signed in as %s, no player name yet: plays wait in the outbox", s.Email)
		} else {
			logf("online: signed in as %s", s.Username)
		}
		writeMe(data)
		writeDaily(data)
		checkNotices(data, true)
	}()
	stop := make(chan struct{})
	// (the rankings looked at again now and then: who passed you)
	go func() {
		t := time.NewTicker(10 * time.Minute)
		defer t.Stop()
		for {
			select {
			case <-stop:
				return
			case <-t.C:
				checkNotices(data, true)
			}
		}
	}()
	go func() {
		last, lastDetail, lastSend := "", "", time.Time{}
		tick := time.NewTicker(300 * time.Millisecond)
		defer tick.Stop()
		for {
			select {
			case <-stop:
				return
			case <-tick.C:
			}
			if b, err := os.ReadFile(filepath.Join(dir, "want.txt")); err == nil {
				// (a line: the chart key and a request number, so asking again for the same chart
				// fetches it again)
				w := strings.TrimSpace(string(b))
				if w != "" && w != last {
					last = w
					chart, _, _ := strings.Cut(w, "\t")
					answerBoard(data, chart)
				}
			}
			// (one score's details, for the song select's score card: online/wantdetail.txt holds
			// the score id and a request number; the answer goes to online/detail/<id>.txt)
			if b, err := os.ReadFile(filepath.Join(dir, "wantdetail.txt")); err == nil {
				w := strings.TrimSpace(string(b))
				if w != "" && w != lastDetail {
					lastDetail = w
					id, _, _ := strings.Cut(w, "\t")
					answerDetail(data, id)
				}
			}
			if time.Since(lastSend) > 4*time.Second {
				lastSend = time.Now()
				sendOutbox(data)
			}
		}
	}()
	return func() {
		close(stop)
		sendOutbox(data)
	}
}

// ---------------------------------------------------------------------------------------------
// a player's profile, for the launcher (anyone's: profiles, ratings and scores are public)

type scoreRow struct {
	ID         int64   `json:"id"`
	Verified   *bool   `json:"verified"` // (missing on a server without v2.sql: every score counts there)
	HasReplay  bool    `json:"has_replay"`
	Valid      bool    `json:"valid"`
	ChartKey   string  `json:"chart_key"`
	Keys       int     `json:"keys"`
	Rate       float64 `json:"rate"`
	Wife       float64 `json:"wife"`
	SSROverall float64 `json:"ssr_overall"`
	MSD        float64 `json:"msd"`
	SongTitle  string  `json:"song_title"`
	SongArtist string  `json:"song_artist"`
	ChartName  string  `json:"chart_name"`
	Marvelous  int     `json:"marvelous"`
	Perfect    int     `json:"perfect"`
	Great      int     `json:"great"`
	Good       int     `json:"good"`
	Bad        int     `json:"bad"`
	Miss       int     `json:"miss"`
	MaxCombo   int     `json:"max_combo"`
	PlayedAt   string  `json:"played_at"`
	Submitted  string  `json:"submitted_at"`
	Source     string  `json:"source"`
}

type playerProfile struct {
	ID        string         `json:"id"`
	Username  string         `json:"username"`
	Since     string         `json:"created_at"`
	Banned    bool           `json:"banned"`
	Avatar    int            `json:"avatar"`
	AvatarExt string         `json:"avatar_ext"`
	Picture   string         `json:"picture"`
	Pinned    []scoreRow     `json:"pinned"`
	Ratings   []playerRating `json:"ratings"`
	Top4      []scoreRow     `json:"top4"`
	Top7      []scoreRow     `json:"top7"`
	Recent    []scoreRow     `json:"recent"`
	Place4    int            `json:"place4"`
	Place7    int            `json:"place7"`
	Scores    int            `json:"scores"`
}

const scoreCols = "id,verified,has_replay,valid,source,chart_key,keys,rate,wife,ssr_overall,msd,song_title,song_artist,chart_name,marvelous,perfect,great,good,bad,miss,max_combo,played_at,submitted_at"

func onlinePlayer(id string) (*playerProfile, error) {
	q := url.QueryEscape(id)
	var ps []playerProfile
	if err := onlineCall("GET", "/rest/v1/profiles?select=id,username,created_at,banned,avatar,avatar_ext&id=eq."+q, nil, "", &ps); err != nil {
		// (a server without v2.sql: no pictures)
		ps = nil
		if err := onlineCall("GET", "/rest/v1/profiles?select=id,username,created_at,banned&id=eq."+q, nil, "", &ps); err != nil {
			return nil, err
		}
	}
	if len(ps) == 0 {
		return nil, errors.New("that player isn't there any more")
	}
	p := &ps[0]
	p.Picture = avatarURL(p.ID, p.Avatar, p.AvatarExt)
	onlineCall("POST", "/rest/v1/rpc/pinned_scores", map[string]any{"player": id}, "", &p.Pinned)
	onlineCall("GET", "/rest/v1/player_ratings?select=*&user_id=eq."+q, nil, "", &p.Ratings)
	onlineCall("POST", "/rest/v1/rpc/top_scores", map[string]any{"player": id, "k": 4, "max_rows": 25}, "", &p.Top4)
	onlineCall("POST", "/rest/v1/rpc/top_scores", map[string]any{"player": id, "k": 7, "max_rows": 25}, "", &p.Top7)
	if onlineCall("GET", "/rest/v1/scores?select="+scoreCols+"&valid=eq.true&order=submitted_at.desc&limit=15&user_id=eq."+q, nil, "", &p.Recent) != nil {
		// (a server without v2.sql's columns)
		onlineCall("GET", "/rest/v1/scores?select="+"valid,"+strings.TrimPrefix(scoreCols, "id,verified,has_replay,valid,source,")+"&valid=eq.true&order=submitted_at.desc&limit=15&user_id=eq."+q, nil, "", &p.Recent)
	}
	// (the place: how many rated players are above, +1)
	for _, r := range p.Ratings {
		if r.Plays == 0 {
			continue
		}
		var above []struct {
			U string `json:"user_id"`
		}
		// (not themselves: the rating as sent back is rounded, so the stored one can read as above it)
		onlineCall("GET", fmt.Sprintf("/rest/v1/player_ratings?select=user_id&keys=eq.%d&plays=gt.0&overall=gt.%s&user_id=neq.%s",
			r.Keys, strconv.FormatFloat(r.Overall, 'g', -1, 64), q), nil, "", &above)
		if r.Keys == 4 {
			p.Place4 = len(above) + 1
		} else if r.Keys == 7 {
			p.Place7 = len(above) + 1
		}
		p.Scores += r.Plays
	}
	return p, nil
}

// ---------------------------------------------------------------------------------------------
// the Online page's extras: what was played lately, one chart's top, a player's rating over time

type activityRow struct {
	ID         int64   `json:"id"`
	UserID     string  `json:"user_id"`
	ChartKey   string  `json:"chart_key"`
	Keys       int     `json:"keys"`
	Rate       float64 `json:"rate"`
	Wife       float64 `json:"wife"`
	SSROverall float64 `json:"ssr_overall"`
	SongTitle  string  `json:"song_title"`
	ChartName  string  `json:"chart_name"`
	PlayedAt   string  `json:"played_at"`
	Source     string  `json:"source"`
	Profile    struct {
		Username  string `json:"username"`
		Avatar    int    `json:"avatar"`
		AvatarExt string `json:"avatar_ext"`
	} `json:"profiles"`
	Picture string `json:"picture"`
}

// onlineActivity: the latest plays of everyone (by when they were played, so a player's older plays
// sent all at once don't fill it)
func onlineActivity(keys int) ([]activityRow, error) {
	var rows []activityRow
	kf := ""
	if keys > 0 {
		kf = fmt.Sprintf("&keys=eq.%d", keys)
	}
	sel := "id,user_id,chart_key,keys,rate,wife,ssr_overall,song_title,chart_name,played_at,source,profiles!scores_user_id_fkey!inner(username,avatar,avatar_ext,banned)"
	err := onlineCall("GET", "/rest/v1/scores?select="+sel+"&valid=eq.true&profiles.banned=eq.false&played_at=not.is.null"+kf+"&order=played_at.desc&limit=200", nil, "", &rows)
	if err != nil {
		// (a server without v2.sql: no avatar column)
		sel = strings.Replace(strings.Replace(sel, "avatar,avatar_ext,", "", 1), "source,", "", 1)
		rows = nil
		err = onlineCall("GET", "/rest/v1/scores?select="+sel+"&valid=eq.true&profiles.banned=eq.false&played_at=not.is.null"+kf+"&order=played_at.desc&limit=200", nil, "", &rows)
	}
	for i := range rows {
		rows[i].Picture = avatarURL(rows[i].UserID, rows[i].Profile.Avatar, rows[i].Profile.AvatarExt)
	}
	return rows, err
}

// onlineBestPlays: the highest-rated plays of everyone (several per player: the launcher keeps one
// per player and chart)
func onlineBestPlays(keys int) ([]activityRow, error) {
	var rows []activityRow
	kf := ""
	if keys > 0 {
		kf = fmt.Sprintf("&keys=eq.%d", keys)
	}
	sel := "id,user_id,chart_key,keys,rate,wife,ssr_overall,song_title,chart_name,played_at,source,profiles!scores_user_id_fkey!inner(username,avatar,avatar_ext,banned)"
	err := onlineCall("GET", "/rest/v1/scores?select="+sel+"&valid=eq.true&verified=eq.true&profiles.banned=eq.false"+kf+"&order=ssr_overall.desc&limit=400", nil, "", &rows)
	for i := range rows {
		rows[i].Picture = avatarURL(rows[i].UserID, rows[i].Profile.Avatar, rows[i].Profile.AvatarExt)
	}
	return rows, err
}

// onlinePlaysOfTheDay: each day's best play, newest first (the server's plays_of_the_day)
func onlinePlaysOfTheDay(keys int) ([]activityRow, error) {
	var flat []struct {
		activityRow
		Day       string `json:"day"`
		Username  string `json:"username"`
		Avatar    int    `json:"avatar"`
		AvatarExt string `json:"avatar_ext"`
	}
	_, off := time.Now().Zone()
	err := onlineCall("POST", "/rest/v1/rpc/plays_of_the_day", map[string]any{"max_days": 5000, "tz_minutes": off / 60, "k": keys}, "", &flat)
	if err != nil {
		return nil, err
	}
	rows := make([]activityRow, 0, len(flat))
	for _, f := range flat {
		r := f.activityRow
		r.Profile.Username, r.Profile.Avatar, r.Profile.AvatarExt = f.Username, f.Avatar, f.AvatarExt
		r.Picture = avatarURL(r.UserID, f.Avatar, f.AvatarExt)
		rows = append(rows, r)
	}
	return rows, nil
}

// onlineChart: one chart's top (each player's best), overall or at one rate (rate 0: any)
func onlineChart(chart string, rate float64) ([]boardRow, error) {
	args := map[string]any{"chart": chart, "max_rows": 50}
	if rate > 0 {
		args["at_rate"] = rate
	}
	var rows []boardRow
	err := onlineCall("POST", "/rest/v1/rpc/chart_leaderboard", args, "", &rows)
	return rows, err
}

type historyPoint struct {
	Day    string     `json:"day"`
	Rating float64    `json:"rating"`
	Plays  []histPlay `json:"plays"` // the day's best plays (by SSR), for the big chart's hover
	N      int        `json:"n"`     // how many plays that day
}

type histPlay struct {
	Chart  string  `json:"chart_key"`
	Title  string  `json:"song_title"`
	Name   string  `json:"chart_name"`
	Rate   float64 `json:"rate"`
	SSR    float64 `json:"ssr_overall"`
	Wife   float64 `json:"wife"`
	Source string  `json:"source"`
}

// onlineHistory works a player's 4K or 7K rating out day by day from their plays, the way the
// server rates them (vh_refresh_rating: the best of each chart at each rate, Etterna's aggregate).
func onlineHistory(id string, keys int) ([]historyPoint, error) {
	type play struct {
		Chart    string  `json:"chart_key"`
		Rate     float64 `json:"rate"`
		Overall  float64 `json:"ssr_overall"`
		Stream   float64 `json:"ssr_stream"`
		JS       float64 `json:"ssr_jumpstream"`
		HS       float64 `json:"ssr_handstream"`
		Stamina  float64 `json:"ssr_stamina"`
		Jack     float64 `json:"ssr_jackspeed"`
		CJ       float64 `json:"ssr_chordjack"`
		Tech     float64 `json:"ssr_technical"`
		Played   string  `json:"played_at"`
		Sent     string  `json:"submitted_at"`
		Verified *bool   `json:"verified"`
		Title    string  `json:"song_title"`
		Name     string  `json:"chart_name"`
		Wife     float64 `json:"wife"`
		Source   string  `json:"source"`
	}
	var plays []play
	q := url.QueryEscape(id)
	cols := "chart_key,rate,ssr_overall,ssr_stream,ssr_jumpstream,ssr_handstream,ssr_stamina,ssr_jackspeed,ssr_chordjack,ssr_technical,played_at,submitted_at,song_title,chart_name,wife"
	path := fmt.Sprintf("/rest/v1/scores?select=%s&user_id=eq.%s&keys=eq.%d&valid=eq.true&limit=10000", cols+",verified,source", q, keys)
	if err := onlineCall("GET", path, nil, "", &plays); err != nil {
		plays = nil
		path = fmt.Sprintf("/rest/v1/scores?select=%s&user_id=eq.%s&keys=eq.%d&valid=eq.true&limit=10000", cols, q, keys)
		if err := onlineCall("GET", path, nil, "", &plays); err != nil {
			return nil, err
		}
	}
	day := func(p play) string {
		s := p.Played
		if s == "" {
			s = p.Sent
		}
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			return t.Local().Format("2006-01-02")
		}
		if len(s) >= 10 {
			return s[:10]
		}
		return s
	}
	kept := plays[:0]
	for _, p := range plays {
		if p.Verified == nil || *p.Verified {
			kept = append(kept, p)
		}
	}
	plays = kept
	sort.SliceStable(plays, func(i, j int) bool { return day(plays[i]) < day(plays[j]) })
	best := map[string]play{}
	var out []historyPoint
	for i := 0; i < len(plays); {
		d := day(plays[i])
		var today []play
		for ; i < len(plays) && day(plays[i]) == d; i++ {
			p := plays[i]
			today = append(today, p)
			k := p.Chart + "@" + strconv.FormatFloat(p.Rate, 'f', 2, 64)
			if b, ok := best[k]; !ok || p.Overall > b.Overall {
				best[k] = p
			}
		}
		// the day's three best plays (one per chart)
		sort.SliceStable(today, func(a, b int) bool { return today[a].Overall > today[b].Overall })
		var top []histPlay
		seen := map[string]bool{}
		for _, p := range today {
			if seen[p.Chart] {
				continue
			}
			seen[p.Chart] = true
			top = append(top, histPlay{Chart: p.Chart, Title: p.Title, Name: p.Name, Rate: p.Rate, SSR: p.Overall, Wife: p.Wife, Source: p.Source})
			if len(top) == 3 {
				break
			}
		}
		var sk [7][]float64
		for _, b := range best {
			for j, v := range []float64{b.Stream, b.JS, b.HS, b.Stamina, b.Jack, b.CJ, b.Tech} {
				sk[j] = append(sk[j], v)
			}
		}
		// (as the server's vh_refresh_rating: 4K the mean of the skillsets, 7K the aggregate of the
		// plays' overall ratings)
		rating := 0.0
		if keys == 7 {
			var ov []float64
			for _, b := range best {
				ov = append(ov, b.Overall)
			}
			rating = etternaAggregate(ov)
		} else {
			for j := 0; j < 7; j++ {
				rating += etternaAggregate(sk[j])
			}
			rating /= 7
		}
		out = append(out, historyPoint{Day: d, Rating: math.Round(rating*100) / 100, Plays: top, N: len(today)})
	}
	return out, nil
}

// etternaAggregate: Etterna's rating from a list of SSRs (the server's vh_aggregate)
func etternaAggregate(ssrs []float64) float64 {
	if len(ssrs) == 0 {
		return 0
	}
	const delta, mult = 0.1, 1.05
	rating, res := 0.0, 10.24
	for i := 0; i < 11; i++ {
		for {
			rating += res
			s := 0.0
			for _, v := range ssrs {
				e := math.Erfc(delta * (v - rating))
				if e > 0 {
					s += math.Max(0, 2/e-2)
				} else {
					s += 1e300
				}
			}
			if !(math.Pow(2, rating*0.1) < s) {
				break
			}
		}
		rating -= res
		res /= 2
	}
	rating += res * 2
	return math.Min(100, math.Max(0, rating*mult))
}

// myPicture: the signed-in player's picture address ("" for none)
func myPicture(s *onlineSession) string {
	var rows []struct {
		Avatar    int    `json:"avatar"`
		AvatarExt string `json:"avatar_ext"`
	}
	if onlineCall("GET", "/rest/v1/profiles?select=avatar,avatar_ext&id=eq."+url.QueryEscape(s.UserID), nil, "", &rows) == nil && len(rows) > 0 {
		return avatarURL(s.UserID, rows[0].Avatar, rows[0].AvatarExt)
	}
	return ""
}

// myPins: the ids of the signed-in player's pinned plays
func myPins(s *onlineSession) []int64 {
	var rows []struct {
		ID int64 `json:"id"`
	}
	onlineCall("POST", "/rest/v1/rpc/pinned_scores", map[string]any{"player": s.UserID}, "", &rows)
	out := make([]int64, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.ID)
	}
	return out
}

// onlinePin pins (or unpins) one of the signed-in player's plays
func onlinePin(score int64, pin bool) error {
	s, err := onlineToken()
	if err != nil {
		return err
	}
	return onlineCall("POST", "/rest/v1/rpc/pin_score", map[string]any{"score": score, "pin": pin}, s.Access, nil)
}

// onlineReorderPins keeps the order the player dragged their pinned plays into
func onlineReorderPins(ids []int64) error {
	s, err := onlineToken()
	if err != nil {
		return err
	}
	return onlineCall("POST", "/rest/v1/rpc/reorder_pins", map[string]any{"ids": ids}, s.Access, nil)
}

// onlineTopBySource: a player's best plays from one game (etterna / osu / lazer / quaver)
func onlineTopBySource(id string, keys int, source string) ([]scoreRow, error) {
	var rows []scoreRow
	// (osu! covers lazer too: one game as far as the player is concerned)
	cond := "source=eq." + url.QueryEscape(source)
	if source == "osu" {
		cond = "source=in.(osu,lazer)"
	}
	err := onlineCall("GET", fmt.Sprintf("/rest/v1/scores?select=%s&user_id=eq.%s&keys=eq.%d&valid=eq.true&verified=eq.true&%s&order=ssr_overall.desc&limit=25",
		scoreCols, url.QueryEscape(id), keys, cond), nil, "", &rows)
	return rows, err
}

// onlineFindPlayers: players whose name has q in it
func onlineFindPlayers(q string) ([]map[string]any, error) {
	var rows []struct {
		ID        string `json:"id"`
		Username  string `json:"username"`
		Avatar    int    `json:"avatar"`
		AvatarExt string `json:"avatar_ext"`
	}
	pat := "*" + strings.NewReplacer("*", "", ",", "", "(", "", ")", "", "\\", "").Replace(q) + "*"
	err := onlineCall("GET", "/rest/v1/profiles?select=id,username,avatar,avatar_ext&banned=eq.false&username=ilike."+url.QueryEscape(pat)+"&limit=20", nil, "", &rows)
	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, map[string]any{"id": r.ID, "username": r.Username, "picture": avatarURL(r.ID, r.Avatar, r.AvatarExt)})
	}
	return out, err
}

// exportScoresCSV writes every score of the signed-in player (valid or not) to a CSV in dir; the
// file's path comes back
func exportScoresCSV(dir string) (string, error) {
	s, err := onlineToken()
	if err != nil {
		return "", err
	}
	cols := []string{"id", "source", "chart_key", "song_title", "song_artist", "chart_name", "keys", "rate", "wife", "ssr_overall", "ssr_stream", "ssr_jumpstream", "ssr_handstream", "ssr_stamina", "ssr_jackspeed", "ssr_chordjack", "ssr_technical", "msd", "marvelous", "perfect", "great", "good", "bad", "miss", "max_combo", "modifiers", "verified", "valid", "played_at", "submitted_at"}
	var all []map[string]any
	for off := 0; ; off += 1000 {
		var rows []map[string]any
		path := fmt.Sprintf("/rest/v1/scores?select=%s&user_id=eq.%s&order=submitted_at.asc&limit=1000&offset=%d", strings.Join(cols, ","), url.QueryEscape(s.UserID), off)
		if err := onlineCall("GET", path, nil, s.Access, &rows); err != nil {
			return "", err
		}
		all = append(all, rows...)
		if len(rows) < 1000 {
			break
		}
	}
	p := filepath.Join(dir, fmt.Sprintf("VSRG Hub scores - %s - %s.csv", s.Username, time.Now().Format("2006-01-02")))
	f, err := os.Create(p)
	if err != nil {
		return "", err
	}
	defer f.Close()
	f.WriteString("\xef\xbb\xbf") // (a BOM: Excel then reads the UTF-8 names right)
	w := csv.NewWriter(f)
	w.Write(cols)
	for _, r := range all {
		rec := make([]string, len(cols))
		for i, c := range cols {
			switch v := r[c].(type) {
			case nil:
				rec[i] = ""
			case float64:
				rec[i] = strconv.FormatFloat(v, 'f', -1, 64)
			case bool:
				rec[i] = strconv.FormatBool(v)
			default:
				rec[i] = fmt.Sprint(v)
			}
		}
		w.Write(rec)
	}
	w.Flush()
	return p, w.Error()
}

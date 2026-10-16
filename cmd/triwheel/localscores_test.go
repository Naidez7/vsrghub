package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInjectLocalScores(t *testing.T) {
	root := t.TempDir()
	ett := filepath.Join(root, "Etterna")
	data := filepath.Join(ett, "Save", "VSRGHub")
	prof := filepath.Join(ett, "Save", "LocalProfiles", "00000000")
	os.MkdirAll(prof, 0o755)
	os.MkdirAll(filepath.Join(ett, "Save"), 0o755)
	os.WriteFile(filepath.Join(ett, "Save", "Preferences.ini"), []byte("[Options]\nDefaultLocalProfileIDP1=00000000\n"), 0o644)
	os.WriteFile(filepath.Join(prof, "Etterna.xml"), []byte(`<?xml version="1.0" encoding="UTF-8"?>
<Stats><GeneralData><DisplayName>Test</DisplayName></GeneralData><PlayerScores><Chart Key="Xaaa" Pack="p" Song="s" Steps="Edit"><ScoresAt PBKey="S1" BestGrade="Tier07" Rate="1.000"><Score Key="S1"><WifeScore>0.99</WifeScore></Score></ScoresAt></Chart></PlayerScores></Stats>`), 0o644)
	for _, sub := range []string{"sent", "osu/replays"} {
		os.MkdirAll(filepath.Join(onlineDir(data), sub), 0o755)
	}
	os.WriteFile(filepath.Join(onlineDir(data), "sent", "O1.json"), []byte(`{"score_key":"O1","chart_key":"Xaaa","keys":4,"rate":1.1,"wife":95.5,"max_combo":120,"modifiers":"osu!","song_title":"S","played_at":"2026-10-16T22:10:00Z","source":"osu","marvelous":100,"perfect":20,"great":3,"good":1,"bad":0,"miss":2,"holds_ng":1}`), 0o644)
	os.WriteFile(filepath.Join(onlineDir(data), "sent", "O2.json"), []byte(`{"score_key":"O2","chart_key":"Xbbb","keys":4,"rate":1,"wife":80,"max_combo":10,"played_at":"2026-10-16T22:10:00Z","source":"quaver","marvelous":5,"miss":2}`), 0o644)
	os.WriteFile(filepath.Join(onlineDir(data), "osu", "replays", "O1"), []byte("48 0.012000 0\n96 -0.004000 1 2\n144 1.000000 2\nH 96 1\n"), 0o644)
	os.WriteFile(filepath.Join(onlineDir(data), "osu", "replays", "O2"), []byte("48 0.012000 0\n"), 0o644)
	n, err := injectLocalScores(ett, data)
	if err != nil || n != 2 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	b, _ := os.ReadFile(filepath.Join(prof, "Etterna.xml"))
	x := string(b)
	for _, want := range []string{`<Score Key="S1">`, `<Score Key="O1">`, `Rate="1.100"`, `<Chart Key="Xbbb"`, `<server>https://api.etternaonline.com</server>`, `<Held>0</Held>`, `<LetGo>1</LetGo>`, `<Grade>Tier10</Grade>`, `<W1>100</W1>`} {
		if !strings.Contains(x, want) {
			t.Errorf("missing %s in\n%s", want, x)
		}
	}
	if _, err := os.Stat(filepath.Join(ett, "Save", "ReplaysV2", "O1")); err != nil {
		t.Error("replay not copied")
	}
	// again: nothing new
	if n, _ := injectLocalScores(ett, data); n != 0 {
		t.Errorf("second run wrote %d", n)
	}
	t.Log(x)
}

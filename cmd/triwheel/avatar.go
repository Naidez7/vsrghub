package main

// Profile pictures for the VSRG Hub rankings: the picture the player picks is cut to a square,
// made 128x128 and sent as avatars/<user id>.png to the server's Storage (public: the rankings show
// it to everyone). profiles.avatar counts the changes, and is part of the picture's address so a
// new one isn't hidden by a cached old one.

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"io"
	"net/http"
	"os"

	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

const avatarSize = 128

// avatarURL: where a player's picture is (version from profiles.avatar; 0: none)
func avatarURL(userID string, version int, ext string) string {
	if version <= 0 || userID == "" {
		return ""
	}
	if ext != "gif" {
		ext = "png"
	}
	return fmt.Sprintf("%s/storage/v1/object/public/avatars/%s.%s?v=%d", onlineURL, userID, ext, version)
}

// a GIF under the server's size limit is sent as it is, so it keeps moving
const avatarGIFMax = 1 << 20

func isGIF(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	var head [6]byte
	n, _ := io.ReadFull(f, head[:])
	return n == 6 && (string(head[:]) == "GIF89a" || string(head[:]) == "GIF87a")
}

// avatarPNG reads a picture (PNG, JPEG, GIF or WebP) and makes the square 128x128 PNG sent.
func avatarPNG(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	src, _, err := image.Decode(io.LimitReader(f, 30<<20))
	if err != nil {
		return nil, errors.New("that file isn't a picture VSRG Hub can read (PNG, JPEG, GIF or WebP)")
	}
	b := src.Bounds()
	side := b.Dx()
	if b.Dy() < side {
		side = b.Dy()
	}
	if side < 8 {
		return nil, errors.New("that picture is too small")
	}
	// the middle square
	x0, y0 := b.Min.X+(b.Dx()-side)/2, b.Min.Y+(b.Dy()-side)/2
	dst := image.NewRGBA(image.Rect(0, 0, avatarSize, avatarSize))
	draw.CatmullRom.Scale(dst, dst.Bounds(), src, image.Rect(x0, y0, x0+side, y0+side), draw.Src, nil)
	var out bytes.Buffer
	if err := (&png.Encoder{CompressionLevel: png.BestCompression}).Encode(&out, dst); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

// onlineSetAvatar sends the picture at path as the signed-in player's; it returns the new version.
func onlineSetAvatar(path string) (int, error) {
	s, err := onlineToken()
	if err != nil {
		return 0, err
	}
	ext, mime := "png", "image/png"
	var img []byte
	if fi, err := os.Stat(path); err == nil && isGIF(path) && fi.Size() <= avatarGIFMax {
		img, err = os.ReadFile(path)
		if err != nil {
			return 0, err
		}
		ext, mime = "gif", "image/gif"
	} else {
		// (a bigger GIF: its first frame, still)
		img, err = avatarPNG(path)
		if err != nil {
			return 0, err
		}
	}
	req, err := http.NewRequest("POST", onlineURL+"/storage/v1/object/avatars/"+s.UserID+"."+ext, bytes.NewReader(img))
	if err != nil {
		return 0, err
	}
	req.Header.Set("apikey", onlineKey)
	req.Header.Set("Authorization", "Bearer "+s.Access)
	req.Header.Set("Content-Type", mime)
	req.Header.Set("x-upsert", "true")
	req.Header.Set("Cache-Control", "max-age=3600")
	resp, err := onlineClient.Do(req)
	if err != nil {
		return 0, errOffline
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		logf("online: picture upload: %s %s", resp.Status, bytes.TrimSpace(body))
		if resp.StatusCode == 404 || bytes.Contains(body, []byte("Bucket not found")) {
			return 0, errors.New("the server isn't ready for pictures yet (its v2.sql hasn't been run)")
		}
		return 0, fmt.Errorf("the picture wasn't taken (%s)", resp.Status)
	}
	var v int
	if err := onlineCall("POST", "/rest/v1/rpc/set_avatar", map[string]any{"ext": ext}, s.Access, &v); err != nil {
		return 0, err
	}
	return v, nil
}

// onlineRemoveAvatar: back to the letter
func onlineRemoveAvatar() error {
	s, err := onlineToken()
	if err != nil {
		return err
	}
	var v int
	return onlineCall("POST", "/rest/v1/rpc/set_avatar", map[string]any{"remove": true}, s.Access, &v)
}

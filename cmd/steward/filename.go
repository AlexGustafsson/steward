package main

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

func FileName(entry indexing.Entry) string {
	albumArtists := make([]string, 0)
	artist := ""
	artists := make([]string, 0)
	album := ""
	trackNumber := ""
	discNumber := ""
	discTotal := 0

	for _, e := range entry.Metadata {
		k, v, ok := strings.Cut(e, "=")
		if !ok {
			continue
		}

		switch k {
		case "ALBUMARTIST":
			albumArtists = append(albumArtists, v)
		case "ARTIST":
			artist = v
		case "ARTISTS":
			artists = append(artists, v)
		case "ALBUM":
			album = v
		case "TRACKNUMBER":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				trackNumber = fmt.Sprintf("%02d", n)
			}
		case "DISCNUMBER":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				discNumber = fmt.Sprintf("%02d", n)
			}
		case "DISCTOTAL":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				discTotal = int(n)
			}
		}
	}

	path := ""

	if len(albumArtists) > 0 {
		path = strings.Join(albumArtists, " ")
	} else if artist != "" {
		path = artist
	} else if len(artists) > 0 {
		path = strings.Join(artists, " ")
	}

	if album != "" {
		if path == "" {
			path = album
		} else {
			path = filepath.Join(path, album)
		}
	}

	path = filepath.Join(path, "Track ")

	if trackNumber == "" {
		path += entry.AudioDigest
	} else {
		path += trackNumber
	}

	if discTotal > 1 && discNumber != "" {
		path += "(CD " + discNumber + ")"
	}

	path += ".flac"

	return path
}

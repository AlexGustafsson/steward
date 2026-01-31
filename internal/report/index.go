package report

import (
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/AlexGustafsson/steward/internal/flac"
)

type Entry struct {
	Name        string
	ModTime     time.Time
	Size        int64
	Metadata    []string
	AudioDigest string
	FileDigest  string
}

// TODO: Doesn't work well with non-CDs
func (e Entry) FileName() string {
	albumArtists := make([]string, 0)
	album := ""
	trackNumber := ""

	for _, e := range e.Metadata {
		k, v, ok := strings.Cut(e, "=")
		if !ok {
			continue
		}

		switch k {
		case "ALBUMARTIST":
			albumArtists = append(albumArtists, v)
		case "ALBUM":
			album = v
		case "TRACKNUMBER":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				trackNumber = fmt.Sprintf("%02d", n)
			}
		}
	}

	path := ""

	if len(albumArtists) > 0 {
		path = strings.Join(albumArtists, " ")
	}

	if album != "" {
		if path == "" {
			path = album
		} else {
			path = filepath.Join(path, album)
		}
	}

	if trackNumber == "" {
		if path == "" {
			path = "Track " + e.AudioDigest
		} else {
			path = filepath.Join(path, "Track "+e.AudioDigest+".flac")
		}
	} else {
		if path == "" {
			path = "Track " + trackNumber
		} else {
			path = filepath.Join(path, "Track "+trackNumber+".flac")
		}
	}

	return path
}

func Index(name string, file *os.File) (Entry, error) {
	stat, err := file.Stat()
	if err != nil {
		return Entry{}, err
	}

	fileHash := sha1.New()

	reader, err := flac.NewFileReader(io.TeeReader(file, fileHash))
	if err != nil {
		return Entry{}, err
	}

	hash := sha1.New()
	metadata := make([]string, 0)
	for {
		r, metadataBlockType, err := reader.NextReader()
		if err == io.EOF {
			break
		} else if err != nil {
			return Entry{}, err
		}

		switch metadataBlockType {
		case 4:
			comment, err := flac.ReadVorbisComment(r)
			if err != nil {
				return Entry{}, err
			}

			for _, field := range comment.Fields {
				metadata = append(metadata, string(field))
			}
			slices.Sort(metadata)
		case -1:
			_, err := io.Copy(hash, r)
			if err != nil {
				return Entry{}, err
			}
		default:
			_, err = io.Copy(io.Discard, r)
			if err != nil {
				return Entry{}, err
			}
		}
	}

	return Entry{
		Name:        name,
		ModTime:     stat.ModTime(),
		Size:        stat.Size(),
		AudioDigest: "sha1:" + hex.EncodeToString(hash.Sum(nil)),
		FileDigest:  "sha1:" + hex.EncodeToString(fileHash.Sum(nil)),
		Metadata:    metadata,
	}, nil
}

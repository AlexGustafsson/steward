package report

import (
	"crypto/sha1"
	"encoding/hex"
	"io"
	"os"
	"slices"
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

package indexing

import (
	"crypto/sha1"
	"encoding/hex"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/AlexGustafsson/steward/internal/flac"
)

type Entry struct {
	Name          string
	ModTime       time.Time
	Size          int64
	Metadata      []string
	AudioDigest   string
	FileDigest    string
	PictureDigest string
}

type IndexDirFunc func(Entry) error

func IndexDir(name string, fn IndexDirFunc) error {
	// TODO: Optimize if necessary, we're bound by IO on the same disk, so likely
	// doesn't make sense to increase thread count
	return filepath.WalkDir(name, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if d.IsDir() || !d.Type().IsRegular() || filepath.Ext(d.Name()) != ".flac" {
			return nil
		}

		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()

		entry, err := IndexFile(path, file)
		if err != nil {
			return err
		}

		return fn(entry)
	})
}

func IndexFile(name string, file *os.File) (Entry, error) {
	stat, err := file.Stat()
	if err != nil {
		return Entry{}, err
	}

	fileHash := sha1.New()

	reader, err := flac.NewFileReader(io.TeeReader(file, fileHash))
	if err != nil {
		return Entry{}, err
	}

	audioHash := sha1.New()
	pictureHash := sha1.New()

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
			_, err := io.Copy(audioHash, r)
			if err != nil {
				return Entry{}, err
			}
		case 6:
			_, err := io.Copy(pictureHash, r)
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
		Name:          name,
		ModTime:       stat.ModTime(),
		Size:          stat.Size(),
		AudioDigest:   "sha1:" + hex.EncodeToString(audioHash.Sum(nil)),
		FileDigest:    "sha1:" + hex.EncodeToString(fileHash.Sum(nil)),
		PictureDigest: "sha1:" + hex.EncodeToString(pictureHash.Sum(nil)),
		Metadata:      metadata,
	}, nil
}

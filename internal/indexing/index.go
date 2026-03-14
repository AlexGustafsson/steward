package indexing

import (
	"crypto/md5"
	"encoding/hex"
	"errors"
	"io"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/AlexGustafsson/steward/internal/flac"
)

// AudioHashMaxSize controls the maximum number of audio bytes to use for
// calculating the audio hash of a file.
// The lower the value, the faster the processing, the higher the value, the
// less likely it is that hashes will collide.
const AudioHashMaxSize = 1024 * 1024 // 1MiB

type Entry struct {
	Name          string
	ModTime       time.Time
	Size          int64
	Metadata      []string
	AudioDigest   string
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
			slog.Warn("Failed to index file", slog.Any("error", err), slog.String("name", file.Name()))
			return nil
		}
		defer file.Close()

		entry, err := IndexFile(path, file)
		if err != nil {
			slog.Warn("Failed to index file", slog.Any("error", err), slog.String("name", file.Name()))
			return nil
		}

		return fn(entry)
	})
}

func IndexFile(name string, file *os.File) (Entry, error) {
	stat, err := file.Stat()
	if err != nil {
		return Entry{}, err
	}

	reader, err := flac.NewFileReader(file)
	if err != nil {
		return Entry{}, err
	}

	audioDataRead := int64(0)
	audioHash := md5.New()
	pictureHash := md5.New()

	metadata := make([]string, 0)
loop:
	for {
		r, metadataBlockType, err := reader.NextReader()
		if errors.Is(err, io.EOF) {
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
			n, err := io.Copy(audioHash, io.LimitReader(r, 1024*1024-audioDataRead))
			if err != nil {
				return Entry{}, err
			}
			audioDataRead += n
			if audioDataRead >= AudioHashMaxSize {
				break loop
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
		AudioDigest:   "md5:" + hex.EncodeToString(audioHash.Sum(nil)),
		PictureDigest: "md5:" + hex.EncodeToString(pictureHash.Sum(nil)),
		Metadata:      metadata,
	}, nil
}

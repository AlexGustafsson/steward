package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"sync"

	"github.com/AlexGustafsson/steward/internal/flac"
)

type Entry struct {
	Path     string   `json:"path"`
	Metadata []string `json:"metadata"`
	Digest   string   `json:"digest"`
}

func readEntry(path string) (Entry, error) {
	file, err := os.Open(path)
	if err != nil {
		return Entry{}, err
	}
	defer file.Close()

	reader, err := flac.NewFileReader(file)
	if err != nil {
		return Entry{}, err
	}

	hash := sha256.New()
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
		Path:     path,
		Digest:   "sha256:" + hex.EncodeToString(hash.Sum(nil)),
		Metadata: metadata,
	}, nil
}

func main() {
	root := os.Args[1]

	var mutex sync.Mutex
	encoder := json.NewEncoder(os.Stdout)

	paths := make(chan string, 128)

	var wg sync.WaitGroup

	// NOTE: 32 threads didn't help performance
	for range 10 {
		wg.Go(func() {
			for path := range paths {
				entry, err := readEntry(path)
				if err != nil {
					slog.Error("Failed to read path", slog.String("path", path), slog.Any("error", err))
					continue
				}

				mutex.Lock()
				encoder.Encode(&entry)
				mutex.Unlock()
			}
		})
	}

	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if d.IsDir() || !d.Type().IsRegular() || filepath.Ext(d.Name()) != ".flac" {
			return nil
		}

		paths <- path

		return nil
	})
	close(paths)
	if err != nil {
		slog.Error("Failed to walk files", slog.Any("error", err))
		// Fallthrough
	}

	wg.Wait()
}

package main

import (
	"encoding/json"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/AlexGustafsson/steward/internal/report"
)

type Entry struct {
	Path        string    `json:"path"`
	Size        int64     `json:"size"`
	ModTime     time.Time `json:"modTime"`
	Metadata    []string  `json:"metadata"`
	AudioDigest string    `json:"audioDigest"`
	FileDigest  string    `json:"fileDigest"`
}

func index(root string) {
	var mutex sync.Mutex
	encoder := json.NewEncoder(os.Stdout)

	paths := make(chan string, 128)

	var wg sync.WaitGroup

	// NOTE: 32 threads didn't help performance. Additionally, just opening the
	// file and then reading it vs actually performing this logic rendered no
	// difference in time across ~2000 files - so additional optimization is
	// likely not needed
	for range 10 {
		wg.Go(func() {
			for path := range paths {
				file, err := os.Open(path)
				if err != nil {
					slog.Error("Failed to open path", slog.String("path", path), slog.Any("error", err))
					continue
				}

				entry, err := report.Index(path, file)
				if err != nil {
					slog.Error("Failed to index path", slog.String("path", path), slog.Any("error", err))
					continue
				}

				mutex.Lock()
				encoder.Encode(&Entry{
					Path:        entry.Name,
					Size:        entry.Size,
					ModTime:     entry.ModTime,
					Metadata:    entry.Metadata,
					AudioDigest: entry.AudioDigest,
					FileDigest:  entry.FileDigest,
				})
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

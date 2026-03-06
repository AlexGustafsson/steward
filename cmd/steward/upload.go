package main

import (
	"bufio"
	"compress/gzip"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/AlexGustafsson/steward/internal/storage"
	"github.com/urfave/cli/v3"
)

func UploadAction(ctx context.Context, cmd *cli.Command) error {
	// During upload, assume it's there if the file name is there, unless forcing
	force := cmd.Bool("force")
	if force {
		slog.Warn("Force enabled - remote files will be overwritten")
	}

	remote, err := storage.NewBlobStorage(cmd.String("to"))
	if err != nil {
		return err
	}

	indexPath := cmd.StringArg("index")
	var reader io.ReadCloser
	if indexPath == "" {
		slog.Debug("Reading index from stdin")
		reader = io.NopCloser(os.Stdin)
	} else {
		slog.Debug("Reading index from file")
		file, err := os.Open(indexPath)
		if err != nil {
			slog.Error("Failed to read index", slog.Any("error", err))
			return ErrExit // TODO Actual error
		}
		defer file.Close()
		reader = file

		if filepath.Ext(indexPath) == ".gz" {
			var err error
			reader, err = gzip.NewReader(reader)
			if err != nil {
				slog.Error("Failed to read index", slog.Any("error", err))
				return ErrExit // TODO Actual error
			}
		}
	}

	uploader, err := storage.NewUploader(ctx, remote, cmd.String("from"))
	if err != nil {
		return err
	}

	totalEntries := uint64(0)
	totalBytes := uint64(0)
	var processedEntries atomic.Uint64
	entriesCh := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			slog.Debug(
				"Upload in progress",
				slog.Uint64("failures", uploader.Failures.Load()),
				slog.Uint64("successes", uploader.Successes.Load()),
				slog.Uint64("uploadedBytes", uploader.UploadedBytes.Load()),
				slog.Uint64("processedBytes", uploader.ProcessedBytes.Load()),
				slog.Uint64("totalEntries", totalEntries),
				slog.Uint64("totalBytes", totalBytes),
				slog.Uint64("processedEntries", processedEntries.Load()),
			)
		}
	}()

	for range 10 {
		wg.Go(func() {
			for entry := range entriesCh {
				logger := slog.With(slog.String("indexName", entry.Name), slog.String("audioDigest", entry.AudioDigest))

				logger.Debug("Processing entry")
				if err := uploader.Upload(ctx, entry, force); err != nil {
					logger.Error("Failed to upload entry", slog.Any("error", err))
				}
			}
		})
	}

	entries := make([]indexing.Entry, 0)
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		var entry indexing.Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			slog.Error("Failed to parse index", slog.Any("error", err))
			break
		}

		entries = append(entries, entry)
		totalEntries++
		totalBytes += uint64(entry.Size)
	}

	for _, entry := range entries {
		entriesCh <- entry
	}
	close(entriesCh)

	wg.Wait()
	ticker.Stop()

	if uploader.Failures.Load() > 0 {
		slog.Error(
			"Upload failed",
			slog.Uint64("failures", uploader.Failures.Load()),
			slog.Uint64("successes", uploader.Successes.Load()),
			slog.Uint64("uploadedBytes", uploader.UploadedBytes.Load()),
			slog.Uint64("processedBytes", uploader.ProcessedBytes.Load()),
			slog.Uint64("totalEntries", totalEntries),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedEntries", processedEntries.Load()),
		)
		return ErrExit
	} else {
		slog.Info(
			"Upload succeeded",
			slog.Uint64("failures", uploader.Failures.Load()),
			slog.Uint64("successes", uploader.Successes.Load()),
			slog.Uint64("uploadedBytes", uploader.UploadedBytes.Load()),
			slog.Uint64("processedBytes", uploader.ProcessedBytes.Load()),
			slog.Uint64("totalEntries", totalEntries),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedEntries", processedEntries.Load()),
		)
	}

	return nil
}

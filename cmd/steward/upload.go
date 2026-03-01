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

	// TODO: Config?
	remote := storage.NewS3Storage(os.Getenv("B2_REGION"), storage.BackBlazeS3Endpoint(os.Getenv("B2_REGION")), os.Getenv("B2_KEY"), os.Getenv("B2_SECRET"), "", cmd.String("to"))

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

	entries := make(chan indexing.Entry, 32)

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
			)
		}
	}()

	for range 10 {
		wg.Go(func() {
			for entry := range entries {
				logger := slog.With(slog.String("indexName", entry.Name), slog.String("audioDigest", entry.AudioDigest))

				logger.Debug("Processing entry")
				if err := uploader.Upload(ctx, entry, force); err != nil {
					logger.Error("Failed to upload entry", slog.Any("error", err))
				}
			}
		})
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		var entry indexing.Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			slog.Error("Failed to parse index", slog.Any("error", err))
			break
		}

		entries <- entry
	}
	close(entries)

	wg.Wait()
	ticker.Stop()

	if uploader.Failures.Load() > 0 {
		slog.Error(
			"Upload failed",
			slog.Uint64("failures", uploader.Failures.Load()),
			slog.Uint64("successes", uploader.Successes.Load()),
			slog.Uint64("uploadedBytes", uploader.UploadedBytes.Load()),
			slog.Uint64("processedBytes", uploader.ProcessedBytes.Load()),
		)
		return ErrExit
	} else {
		slog.Info(
			"Upload succeeded",
			slog.Uint64("failures", uploader.Failures.Load()),
			slog.Uint64("successes", uploader.Successes.Load()),
			slog.Uint64("uploadedBytes", uploader.UploadedBytes.Load()),
			slog.Uint64("processedBytes", uploader.ProcessedBytes.Load()),
		)
	}

	return nil
}

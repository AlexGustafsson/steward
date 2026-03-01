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

func DownloadAction(ctx context.Context, cmd *cli.Command) error {
	// During download, assume it's there if the file name is there, unless forcing
	force := cmd.Bool("force")
	if force {
		slog.Warn("Force enabled - local files will be overwritten")
	}

	// TODO: Config?
	remote := storage.NewS3Storage(os.Getenv("B2_REGION"), storage.BackBlazeS3Endpoint(os.Getenv("B2_REGION")), os.Getenv("B2_KEY"), os.Getenv("B2_SECRET"), "", cmd.String("from"))

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

	downloader, err := storage.NewDownloader(ctx, remote, cmd.String("to"))
	if err != nil {
		return err
	}

	entries := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			slog.Debug(
				"Download in progress",
				slog.Uint64("failures", downloader.Failures.Load()),
				slog.Uint64("successes", downloader.Successes.Load()),
				slog.Uint64("downloadedBytes", downloader.DownloadedBytes.Load()),
				slog.Uint64("processedBytes", downloader.ProcessedBytes.Load()),
			)
		}
	}()

	for range 10 {
		wg.Go(func() {
			// NOTE: Assumes that all entries are interesting, whereas when uploading,
			// files are diffed and ignored if they already exist remotely. So index
			// diffing is carried out beforehand
			for entry := range entries {
				logger := slog.With(slog.String("indexName", entry.Name), slog.String("audioDigest", entry.AudioDigest))

				logger.Debug("Processing entry")
				if err := downloader.Download(ctx, entry, force); err != nil {
					logger.Error("Failed to download entry", slog.Any("error", err))
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

	if downloader.Failures.Load() > 0 {
		slog.Error(
			"Download failed",
			slog.Uint64("failures", downloader.Failures.Load()),
			slog.Uint64("successes", downloader.Successes.Load()),
			slog.Uint64("downloadedBytes", downloader.DownloadedBytes.Load()),
			slog.Uint64("processedBytes", downloader.ProcessedBytes.Load()),
		)
		os.Exit(1)
	} else {
		slog.Info(
			"Download succeeded",
			slog.Uint64("failures", downloader.Failures.Load()),
			slog.Uint64("successes", downloader.Successes.Load()),
			slog.Uint64("downloadedBytes", downloader.DownloadedBytes.Load()),
			slog.Uint64("processedBytes", downloader.ProcessedBytes.Load()),
		)
	}

	return nil
}

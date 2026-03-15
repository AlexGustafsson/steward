package main

import (
	"bufio"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"

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

	remote, err := storage.NewBlobStorage(cmd.String("from"))
	if err != nil {
		return err
	}

	// When downloading, an index is required. Use "-" convention to signal
	// reading from stdin
	indexPath := cmd.StringArg("index")
	var reader io.ReadCloser
	if indexPath == "" {
		return fmt.Errorf("no index specified")
	} else if indexPath == "-" {
		slog.Debug("Reading index from stdin")
		reader = io.NopCloser(os.Stdin)
	} else if indexPath != "" {
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

	downloader, err := storage.NewDownloader(ctx, remote, cmd.String("to"), force)
	if err != nil {
		return err
	}

	totalEntries := uint64(0)
	totalBytes := uint64(0)
	entriesCh := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	go func() {
		signals := make(chan os.Signal, 1)
		signal.Notify(signals, syscall.SIGINFO)
		for range signals {
			slog.Info(
				"Download status",
				slog.Uint64("total", totalEntries),
				slog.Uint64("failures", downloader.Failures.Load()),
				slog.Uint64("successes", downloader.Successes.Load()),
				slog.Uint64("downloadedBytes", downloader.DownloadedBytes.Load()),
				slog.Uint64("totalBytes", totalBytes),
			)
		}
	}()

	for range cmd.Int("parallelism") {
		wg.Go(func() {
			// NOTE: Assumes that all entries are interesting, whereas when uploading,
			// files are diffed and ignored if they already exist remotely. So index
			// diffing is carried out beforehand
			for entry := range entriesCh {
				logger := slog.With(slog.String("indexName", entry.Name), slog.String("audioDigest", entry.AudioDigest))

				logger.Debug("Processing entry")
				err := downloader.Download(ctx, entry)
				if err != nil {
					logger.Error("Failed to download entry", slog.Any("error", err))
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

	// Bail if there are files that would be overwritten
	fileNames := make(map[string]struct{})
	for _, entry := range entries {
		name := storage.DefaultFileNameFunc(entry)
		if _, ok := fileNames[name]; ok {
			return fmt.Errorf("duplicate target files for path: <%s> (%s)", name, entry.AudioDigest)
		}

		fileNames[name] = struct{}{}
	}

	for _, entry := range entries {
		entriesCh <- entry
	}
	close(entriesCh)

	wg.Wait()

	if downloader.Failures.Load() > 0 {
		slog.Error(
			"Download failed",
			slog.Uint64("total", totalEntries),
			slog.Uint64("failures", downloader.Failures.Load()),
			slog.Uint64("successes", downloader.Successes.Load()),
			slog.Uint64("downloadedBytes", downloader.DownloadedBytes.Load()),
			slog.Uint64("totalBytes", totalBytes),
		)
		os.Exit(1)
	} else {
		slog.Info(
			"Download succeeded",
			slog.Uint64("total", totalEntries),
			slog.Uint64("failures", downloader.Failures.Load()),
			slog.Uint64("successes", downloader.Successes.Load()),
			slog.Uint64("downloadedBytes", downloader.DownloadedBytes.Load()),
			slog.Uint64("totalBytes", totalBytes),
		)
	}

	return nil
}

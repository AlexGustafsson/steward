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
	"strings"
	"sync"
	"sync/atomic"
	"syscall"

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

	// When upload, an index is not required if a just-in-time index is created.
	// Use "-" convention to signal reading from stdin
	indexPath := cmd.StringArg("index")
	var reader io.ReadCloser
	if indexPath == "-" {
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

	uploader, err := storage.NewUploader(ctx, remote, cmd.String("from"))
	if err != nil {
		return err
	}

	totalEntries := uint64(0)
	totalBytes := uint64(0)
	var processedEntries atomic.Uint64
	entriesCh := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	go func() {
		signals := make(chan os.Signal, 1)
		signal.Notify(signals, syscall.SIGINFO)
		for range signals {
			slog.Info(
				"Upload status",
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

	for range cmd.Int("parallelism") {
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

	// If no index is specified, create an index just-in-time
	entries := make([]indexing.Entry, 0)
	if reader == nil {
		slog.Info("No index specified, creating one just-in-time")
		err := indexing.IndexDir(cmd.String("from"), func(e indexing.Entry) error {
			entries = append(entries, e)
			return nil
		})
		if err != nil {
			return err
		}
		slog.Info("Index created successfully")
	} else {
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
	}

	for _, entry := range entries {
		entriesCh <- entry
	}
	close(entriesCh)

	wg.Wait()

	failed := uploader.Failures.Load() > 0

	if !failed {
		tags := cmd.StringSlice("tag")
		if len(tags) > 0 {
			for _, tag := range tags {
				pathPrefix := ""
				if strings.Contains(tag, ":") {
					pathPrefix, tag, _ = strings.Cut(tag, ":")
				}

				indexID, err := uploader.UploadIndex(ctx, pathPrefix, tag)
				if err == nil {
					slog.Info("Successfully uploaded index", slog.String("indexId", indexID))
					fmt.Println(indexID)
				} else {
					slog.Warn("Failed to upload index", slog.Any("error", err))
					failed = true
					// Fallthrough
				}
			}
		} else {
			indexID, err := uploader.UploadIndex(ctx, "", "")
			if err == nil {
				slog.Info("Successfully uploaded index", slog.String("indexId", indexID))
				fmt.Println(indexID)
			} else {
				slog.Warn("Failed to upload index", slog.Any("error", err))
				failed = true
				// Fallthrough
			}
		}
	}

	if failed {
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

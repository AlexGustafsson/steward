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
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/AlexGustafsson/steward/internal/rclone"
	rclonefs "github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/accounting"
	"github.com/rclone/rclone/fs/operations"
	"github.com/urfave/cli/v3"
)

func DownloadAction(ctx context.Context, cmd *cli.Command) error {
	ctx = operations.WithLogger(ctx, operations.LoggerFn(func(ctx context.Context, sigil operations.Sigil, src, dst rclonefs.DirEntry, err error) {
		log := slog.With(slog.String("name", src.Remote()))

		switch sigil {
		case operations.MissingOnSrc:
			log.Debug("Remote file is missing locally")
		case operations.Match:
			log.Debug("Local and remote files match")
		case operations.Differ:
			log.Debug("Local and remote files differ")
		case operations.TransferError:
			log.Warn("Failed to download file")
		}
	}))
	ctx = accounting.WithStatsGroup(ctx, "download")

	remoteFS, err := rclone.GetFS(ctx, cmd.String("from"))
	if err != nil {
		slog.Error("Failed to read index", slog.Any("error", err))
		os.Exit(1)
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

	entries := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	var failures atomic.Uint64
	var successes atomic.Uint64

	var totalBytes uint64
	var processedBytes atomic.Uint64

	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			v := accounting.Stats(ctx)
			progress := float64(processedBytes.Load()) / float64(totalBytes)
			slog.Debug(
				"Download in progress",
				slog.Float64("progress", progress),
				slog.Uint64("totalBytes", totalBytes),
				slog.Uint64("processedBytes", processedBytes.Load()),
				slog.Int64("downloadedBytes", v.GetBytes()),
				slog.Int64("transfers", v.GetTransfers()),
				slog.Int64("checks", v.GetChecks()),
				slog.Int64("errors", v.GetErrors()),
				slog.Int64("bytesPending", v.GetBytesWithPending()),
				slog.Any("lastError", v.GetLastError()),
			)
		}
	}()

	for range 10 {
		wg.Go(func() {
			for entry := range entries {
				// NOTE: The index controls what files exist locally, so rerunning the
				// command without rebuilding the index will re-download all files
				diffFS := &rclone.DiffFS{Entry: rclone.Entry{
					Name:        entry.Name,
					ModTime:     entry.ModTime,
					Size:        entry.Size,
					Metadata:    entry.Metadata,
					AudioDigest: entry.AudioDigest,
				}}
				algorithm, digest, _ := strings.Cut(entry.AudioDigest, ":")
				name := filepath.Join("blobs", algorithm, digest)
				slog.Debug("Processing entry", slog.String("name", name))
				err := rclone.Copy(ctx, remoteFS, name, diffFS, cmd.String("to"))
				processedBytes.Add(uint64(entry.Size))
				if err == nil {
					successes.Add(1)
				} else {
					slog.Warn("Failed to download entry", slog.Any("error", err))
					failures.Add(1)
					// Fallthrough
				}
			}
		})
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		var entry indexing.Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			slog.Error("Failed to parse index", slog.Any("error", err))
			failures.Add(1)
			break
		}

		totalBytes += uint64(entry.Size)
		entries <- entry
	}
	close(entries)

	wg.Wait()
	ticker.Stop()

	v := accounting.Stats(ctx)

	progress := float64(processedBytes.Load()) / float64(totalBytes)
	if failures.Load() > 0 {
		slog.Error(
			"Download failed",
			slog.Uint64("failures", failures.Load()),
			slog.Uint64("successes", successes.Load()),

			slog.Float64("progress", progress),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedBytes", processedBytes.Load()),
			slog.Int64("downloadedBytes", v.GetBytes()),
			slog.Int64("transfers", v.GetTransfers()),
			slog.Int64("checks", v.GetChecks()),
			slog.Int64("errors", v.GetErrors()),
			slog.Int64("bytesPending", v.GetBytesWithPending()),
			slog.Any("lastError", v.GetLastError()),
		)
		os.Exit(1)
	} else {
		slog.Info(
			"Download succeeded",
			slog.Uint64("failures", failures.Load()),
			slog.Uint64("successes", successes.Load()),

			slog.Float64("progress", progress),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedBytes", processedBytes.Load()),
			slog.Int64("downloadedBytes", v.GetBytes()),
			slog.Int64("transfers", v.GetTransfers()),
			slog.Int64("checks", v.GetChecks()),
			slog.Int64("errors", v.GetErrors()),
			slog.Int64("bytesPending", v.GetBytesWithPending()),
			slog.Any("lastError", v.GetLastError()),
		)
	}

	return nil
}

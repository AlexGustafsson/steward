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

func UploadAction(ctx context.Context, cmd *cli.Command) error {
	// During upload, assume it's there if the file name is there, unless forcing
	force := cmd.Bool("force")
	if force {
		slog.Warn("Force enabled - remote file metadata will be overwritten")
	}

	ctx = operations.WithEqualFn(ctx, func(ctx context.Context, src rclonefs.ObjectInfo, dst rclonefs.Object) bool {
		log := slog.With(slog.String("name", src.Remote()))

		// Leave it to rclone to decide, best effort
		if force {
			equal := operations.Equal(ctx, src, dst)

			// TODO: This is a workaround for logger not being called when equal fn
			// returns true
			if equal {
				log.Debug("Skipping file with equal content")
			}
			return equal
		}

		srcIndexObject, ok := src.(*rclone.IndexObject)
		if !ok {
			panic("unknown source object")
		}

		algorithm, digest, _ := strings.Cut(srcIndexObject.Entry().AudioDigest, ":")
		expectedPath := filepath.Join("blobs", algorithm, digest)

		// TODO: The contents could technically still differ, but for now let's not
		// bother. If it's an issue, use force to perform hash-based matching
		// instead Note that the important content is the audio data. Changes in
		// metadata is not important when comparing the blobs as that can be
		// restored separately, but remotes like B2 will report the actual file hash
		equal := dst.Remote() == expectedPath

		// TODO: This is a workaround for logger not being called when equal fn
		// returns true
		if equal {
			log.Debug("Skipping file already in remote list")
		}
		return equal
	})

	// TODO: Not called when equal fn returns true?
	ctx = operations.WithLogger(ctx, operations.LoggerFn(func(ctx context.Context, sigil operations.Sigil, src, dst rclonefs.DirEntry, err error) {
		log := slog.With(slog.String("name", src.Remote()))

		switch sigil {
		case operations.MissingOnDst:
			log.Debug("Local file is missing on remote")
		case operations.Match:
			log.Debug("Local and remote files match")
		case operations.Differ:
			log.Debug("Local and remote files differ")
		case operations.TransferError:
			log.Warn("Failed to upload file")
		}
	}))
	ctx = accounting.WithStatsGroup(ctx, "upload")

	remoteFS, err := rclone.GetFS(ctx, cmd.String("to"))
	if err != nil {
		slog.Error("Failed to get remote", slog.Any("error", err))
		return ErrExit // TODO Actual error
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
				"Upload in progress",
				slog.Float64("progress", progress),
				slog.Uint64("totalBytes", totalBytes),
				slog.Uint64("processedBytes", processedBytes.Load()),
				slog.Int64("uploadedBytes", v.GetBytes()),
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
				slog.Debug("Processing entry", slog.String("name", entry.Name))
				indexFS := &rclone.IndexFS{Entry: rclone.Entry{
					Name:        entry.Name,
					ModTime:     entry.ModTime,
					Size:        entry.Size,
					Metadata:    entry.Metadata,
					AudioDigest: entry.AudioDigest,
					FileDigest:  entry.FileDigest,
				}}
				algorithm, digest, _ := strings.Cut(entry.AudioDigest, ":")
				name := filepath.Join("blobs", algorithm, digest)

				err := rclone.Copy(ctx, indexFS, entry.Name, remoteFS, name)
				processedBytes.Add(uint64(entry.Size))
				if err == nil {
					successes.Add(1)
				} else {
					slog.Warn("Failed to upload entry", slog.Any("error", err))
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
			"Upload failed",
			slog.Uint64("failures", failures.Load()),
			slog.Uint64("successes", successes.Load()),

			slog.Float64("progress", progress),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedBytes", processedBytes.Load()),
			slog.Int64("uploadedBytes", v.GetBytes()),
			slog.Int64("transfers", v.GetTransfers()),
			slog.Int64("checks", v.GetChecks()),
			slog.Int64("errors", v.GetErrors()),
			slog.Int64("bytesPending", v.GetBytesWithPending()),
			slog.Any("lastError", v.GetLastError()),
		)
		return ErrExit // TODO Actual error
	} else {
		slog.Info(
			"Upload succeeded",
			slog.Uint64("failures", failures.Load()),
			slog.Uint64("successes", successes.Load()),

			slog.Float64("progress", progress),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedBytes", processedBytes.Load()),
			slog.Int64("uploadedBytes", v.GetBytes()),
			slog.Int64("transfers", v.GetTransfers()),
			slog.Int64("checks", v.GetChecks()),
			slog.Int64("errors", v.GetErrors()),
			slog.Int64("bytesPending", v.GetBytesWithPending()),
			slog.Any("lastError", v.GetLastError()),
		)
	}

	return nil
}

package main

import (
	"bufio"
	"compress/gzip"
	"context"
	"crypto/md5"
	"encoding/hex"
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

	entries := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	var failures atomic.Uint64
	var successes atomic.Uint64

	var totalBytes uint64
	var processedBytes atomic.Uint64

	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			// TODO: Reimplement stats gathering
			// v := accounting.Stats(ctx)
			// progress := float64(processedBytes.Load()) / float64(totalBytes)
			// slog.Debug(
			// 	"Upload in progress",
			// 	slog.Float64("progress", progress),
			// 	slog.Uint64("totalBytes", totalBytes),
			// 	slog.Uint64("processedBytes", processedBytes.Load()),
			// 	slog.Int64("uploadedBytes", v.GetBytes()),
			// 	slog.Int64("transfers", v.GetTransfers()),
			// 	slog.Int64("checks", v.GetChecks()),
			// 	slog.Int64("errors", v.GetErrors()),
			// 	slog.Int64("bytesPending", v.GetBytesWithPending()),
			// 	slog.Any("lastError", v.GetLastError()),
			// )
		}
	}()

	// List all remote blobs
	blobs, err := remote.GetBlobs(ctx)
	if err != nil {
		return err
	}

	for range 10 {
		wg.Go(func() {
			for entry := range entries {
				slog.Debug("Processing entry", slog.String("name", entry.Name))

				audioDigestAlgorithm, audioDigest, _ := strings.Cut(entry.AudioDigest, ":")
				blobKey := filepath.Join("blobs", audioDigestAlgorithm, audioDigest)

				blobEntry, blobEntryExists := blobs[blobKey]
				if blobEntryExists {
					if force {
						slog.Debug("Local file name already exists but force enabled - uploading")
					} else {
						slog.Debug("Local file name already exists - skipping")
						continue
					}
				} else {
					slog.Debug("Local file missing in remote - uploading")
				}

				file, err := os.Open(entry.Name)
				if err != nil {
					slog.Warn("Failed to upload entry", slog.Any("error", err))
					failures.Add(1)
					continue
				}

				md5sum := md5.New()

				_, err = io.Copy(md5sum, file)
				if err != nil {
					slog.Warn("Failed to upload entry", slog.Any("error", err))
					failures.Add(1)
					file.Close()
					continue
				}

				_, err = file.Seek(0, 0)
				if err != nil {
					slog.Warn("Failed to upload entry", slog.Any("error", err))
					failures.Add(1)
					file.Close()
					continue
				}

				fileDigest := "md5:" + hex.EncodeToString(md5sum.Sum(nil))

				if blobEntryExists && blobEntry.Digest == fileDigest {
					slog.Debug("Local file matches remote - skipping")
					file.Close()
					continue
				}

				err = remote.PutBlob(ctx, blobKey, file, fileDigest)
				file.Close()
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

	// v := accounting.Stats(ctx)

	// progress := float64(processedBytes.Load()) / float64(totalBytes)
	if failures.Load() > 0 {
		// slog.Error(
		// 	"Upload failed",
		// 	slog.Uint64("failures", failures.Load()),
		// 	slog.Uint64("successes", successes.Load()),

		// 	slog.Float64("progress", progress),
		// 	slog.Uint64("totalBytes", totalBytes),
		// 	slog.Uint64("processedBytes", processedBytes.Load()),
		// 	slog.Int64("uploadedBytes", v.GetBytes()),
		// 	slog.Int64("transfers", v.GetTransfers()),
		// 	slog.Int64("checks", v.GetChecks()),
		// 	slog.Int64("errors", v.GetErrors()),
		// 	slog.Int64("bytesPending", v.GetBytesWithPending()),
		// 	slog.Any("lastError", v.GetLastError()),
		// )
		return ErrExit // TODO Actual error
	} else {
		// slog.Info(
		// 	"Upload succeeded",
		// 	slog.Uint64("failures", failures.Load()),
		// 	slog.Uint64("successes", successes.Load()),

		// 	slog.Float64("progress", progress),
		// 	slog.Uint64("totalBytes", totalBytes),
		// 	slog.Uint64("processedBytes", processedBytes.Load()),
		// 	slog.Int64("uploadedBytes", v.GetBytes()),
		// 	slog.Int64("transfers", v.GetTransfers()),
		// 	slog.Int64("checks", v.GetChecks()),
		// 	slog.Int64("errors", v.GetErrors()),
		// 	slog.Int64("bytesPending", v.GetBytesWithPending()),
		// 	slog.Any("lastError", v.GetLastError()),
		// )
	}

	return nil
}

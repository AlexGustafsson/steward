package main

import (
	"bufio"
	"compress/gzip"
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"errors"
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

	entries := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	var stats storage.ReadStats

	var failures atomic.Uint64
	var successes atomic.Uint64

	var totalBytes uint64
	var processedBytes atomic.Uint64

	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			progress := float64(processedBytes.Load()) / float64(totalBytes)
			slog.Debug(
				"Download in progress",
				slog.Float64("progress", progress),
				slog.Uint64("totalBytes", totalBytes),
				slog.Uint64("processedBytes", processedBytes.Load()),
				slog.Uint64("downloadedBytes", stats.Bytes.Load()),
			)
		}
	}()

	// List all remote blobs
	blobs, err := remote.GetBlobs(ctx)
	if err != nil {
		return err
	}

	for range 10 {
		wg.Go(func() {
			// NOTE: Assumes that all entries are interesting, whereas when uploading,
			// files are diffed and ignored if they already exist remotely. So index
			// diffing is carried out beforehand
			for entry := range entries {
				slog.Debug("Processing entry", slog.String("name", entry.Name))

				audioDigestAlgorithm, audioDigest, _ := strings.Cut(entry.AudioDigest, ":")
				blobKey := filepath.Join("blobs", audioDigestAlgorithm, audioDigest)

				blobEntry, blobEntryExists := blobs[blobKey]
				if !blobEntryExists {
					slog.Warn("Indexed file does not exist in remote storage")
					continue
				}

				name := filepath.Join(cmd.String("to"), FileName(entry))

				err = os.MkdirAll(filepath.Dir(name), os.ModePerm)
				if err != nil {
					slog.Warn("Failed to download entry", slog.Any("error", err))
					failures.Add(1)
					continue
				}

				fileExists := true
				file, err := os.OpenFile(name, os.O_RDWR, 0644)
				if errors.Is(err, os.ErrNotExist) {
					fileExists = false
					file, err = os.OpenFile(name, os.O_WRONLY|os.O_CREATE, 0644)
				}
				if err != nil {
					slog.Warn("Failed to download entry", slog.Any("error", err))
					failures.Add(1)
					continue
				}

				if fileExists {
					if force {
						slog.Debug("Local file name already exists but force enabled - downloading")

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

						if blobEntry.Digest == fileDigest {
							slog.Debug("Local file matches remote - skipping")
							file.Close()
							continue
						}
					} else {
						slog.Debug("Local file name already exists - skipping")
						continue
					}
				}

				r, _, err := remote.GetBlob(ctx, blobKey)

				n, err := io.Copy(file, stats.NewReader(r))
				file.Close()
				processedBytes.Add(uint64(n))
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

	progress := float64(processedBytes.Load()) / float64(totalBytes)
	if failures.Load() > 0 {
		slog.Error(
			"Download failed",
			slog.Uint64("failures", failures.Load()),
			slog.Uint64("successes", successes.Load()),

			slog.Float64("progress", progress),
			slog.Uint64("totalBytes", totalBytes),
			slog.Uint64("processedBytes", processedBytes.Load()),
			slog.Uint64("downloadedBytes", stats.Bytes.Load()),
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
			slog.Uint64("downloadedBytes", stats.Bytes.Load()),
		)
	}

	return nil
}

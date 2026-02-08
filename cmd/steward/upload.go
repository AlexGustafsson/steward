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
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/AlexGustafsson/steward/internal/rclone"
	rclonefs "github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/accounting"
	"github.com/rclone/rclone/fs/operations"
)

func upload(remote string, indexPath string) {
	ctx := context.Background()

	// During upload, assume it's there if the file name is there, unless forcing
	force := false
	ctx = operations.WithEqualFn(ctx, func(ctx context.Context, src rclonefs.ObjectInfo, dst rclonefs.Object) bool {
		// Leave it to rclone to decide, best effort
		if force {
			return operations.Equal(ctx, src, dst)
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
		return dst.Remote() == expectedPath
	})

	// TODO: Not called when equal fn returns true?
	ctx = operations.WithLogger(ctx, operations.LoggerFn(func(ctx context.Context, sigil operations.Sigil, src, dst rclonefs.DirEntry, err error) {
		switch sigil {
		case operations.MissingOnSrc:
			fmt.Println(src.Remote(), "is missing locally")
		case operations.MissingOnDst:
			fmt.Println(src.Remote(), "is missing on remote")
		case operations.Match:
			fmt.Println(src.Remote(), "match")
		case operations.Differ:
			fmt.Println(src.Remote(), "differ")
		case operations.TransferError:
			fmt.Println(src.Remote(), "failed")
		default:
			fmt.Println(src.Remote(), sigil)
		}
	}))
	ctx = accounting.WithStatsGroup(ctx, "upload")

	remoteFS, err := rclone.GetFS(ctx, remote)
	if err != nil {
		slog.Error("Failed to read index", slog.Any("error", err))
		os.Exit(1)
	}

	var reader io.ReadCloser
	if indexPath == "" {
		reader = io.NopCloser(os.Stdin)
	} else {
		file, err := os.Open(indexPath)
		if err != nil {
			slog.Error("Failed to read index", slog.Any("error", err))
			os.Exit(1)
		}
		defer file.Close()
		reader = file

		if filepath.Ext(indexPath) == ".gz" {
			var err error
			reader, err = gzip.NewReader(reader)
			if err != nil {
				slog.Error("Failed to read index", slog.Any("error", err))
				os.Exit(1)
			}
		}
	}

	entries := make(chan indexing.Entry, 32)

	var wg sync.WaitGroup

	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			v := accounting.Stats(ctx)
			fmt.Println(v.String())
		}
	}()

	failures := 0
	for range 10 {
		wg.Go(func() {
			for entry := range entries {
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
				rclone.Copy(ctx, indexFS, entry.Name, remoteFS, name)
			}
		})
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		var entry indexing.Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			slog.Error("Failed to parse index", slog.Any("error", err))
			failures++
			break
		}

		entries <- entry
	}
	close(entries)

	wg.Wait()
	ticker.Stop()

	if failures > 0 {
		os.Exit(1)
	}
}

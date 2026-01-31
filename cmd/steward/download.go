package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/AlexGustafsson/steward/internal/rclone"
	rclonefs "github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/accounting"
	"github.com/rclone/rclone/fs/operations"
)

func download(remote string, a string, b string) {
	entriesA, err := readEntries(a)
	if err != nil {
		panic(err)
	}

	entriesB, err := readEntries(b)
	if err != nil {
		panic(err)
	}

	missing := make([]rclone.Entry, 0)

	// TODO: Optimize if necessary
	for _, entryB := range entriesB {
		_, ok := slices.BinarySearchFunc(entriesA, entryB.AudioDigest, func(entryA Entry, digest string) int {
			return strings.Compare(entryA.AudioDigest, digest)
		})
		if !ok {
			missing = append(missing, rclone.Entry{
				Name:        entryB.Path,
				ModTime:     entryB.ModTime,
				Size:        entryB.Size,
				Metadata:    entryB.Metadata,
				AudioDigest: entryB.AudioDigest,
				FileDigest:  entryB.FileDigest,
			})
		}
	}

	fmt.Println("Found", len(missing), "missing item(s)")

	ctx := context.Background()

	ctx = operations.WithLogger(ctx, operations.LoggerFn(func(ctx context.Context, sigil operations.Sigil, src, dst rclonefs.DirEntry, err error) {
		switch sigil {
		case operations.MissingOnSrc:
			fmt.Println(src.Remote(), "is missing on remote")
		case operations.MissingOnDst:
			fmt.Println(src.Remote(), "is missing locally")
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

	entries := make(chan rclone.Entry, 32)

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
				// NOTE: The index controls what files exist locally, so rerunning the
				// command without rebuilding the index will re-download all files
				diffFS := &rclone.DiffFS{Entry: entry}
				algorithm, digest, _ := strings.Cut(entry.AudioDigest, ":")
				name := filepath.Join("blobs", algorithm, digest)
				fmt.Println("Downloading", name, "to ./")
				rclone.Copy(ctx, remoteFS, name, diffFS, "./")
			}
		})
	}

	for _, entry := range missing {
		entries <- entry
	}
	close(entries)

	wg.Wait()
	ticker.Stop()

	if failures > 0 {
		os.Exit(1)
	}
}

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

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/AlexGustafsson/steward/internal/storage"
	"github.com/urfave/cli/v3"
)

func UploadIndexAction(ctx context.Context, cmd *cli.Command) error {
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
	} else {
		return fmt.Errorf("missing required index id")
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
	}

	remote, err := storage.NewBlobStorage(cmd.String("to"))
	if err != nil {
		return err
	}

	indexID, err := storage.UploadIndex(ctx, remote, entries, cmd.String("tag"))
	if err == nil {
		slog.Info("Successfully uploaded index", slog.String("indexId", indexID))
		fmt.Println(indexID)
	} else {
		slog.Error("Failed to upload index", slog.Any("error", err))
		return ErrExit
	}

	return nil
}

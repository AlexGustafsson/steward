package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/AlexGustafsson/steward/internal/storage"
	"github.com/urfave/cli/v3"
)

func DownloadIndexAction(ctx context.Context, cmd *cli.Command) error {
	indexID := cmd.StringArg("index")
	if indexID == "" {
		return fmt.Errorf("missing required argument index id")
	}

	remote, err := storage.NewBlobStorage(cmd.String("from"))
	if err != nil {
		return err
	}

	entries, err := storage.DownloadIndex(ctx, remote, indexID)
	if err != nil {
		return err
	}

	encoder := json.NewEncoder(os.Stdout)
	for _, entry := range entries {
		err := encoder.Encode(&entry)
		if err != nil {
			return err
		}
	}

	return nil
}

package main

import (
	"context"
	"encoding/json"
	"os"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/urfave/cli/v3"
)

func IndexAction(ctx context.Context, cmd *cli.Command) error {
	root := cmd.StringArg("root")
	if root == "" {
		_ = cli.ShowAppHelp(cmd)
		return ErrExit
	}

	encoder := json.NewEncoder(os.Stdout)
	return indexing.IndexDir(root, func(e indexing.Entry) error {
		return encoder.Encode(&e)
	})
}

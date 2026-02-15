package main

import (
	"context"
	"encoding/json"
	"os"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/urfave/cli/v3"
)

func IndexAction(ctx context.Context, cmd *cli.Command) error {
	args := cmd.Args()
	if args.Len() == 0 {
		_ = cli.ShowAppHelp(cmd)
		return ErrExit
	}

	encoder := json.NewEncoder(os.Stdout)
	for i := 0; i < args.Len(); i++ {
		err := indexing.IndexDir(args.Get(i), func(e indexing.Entry) error {
			return encoder.Encode(&e)
		})
		if err != nil {
			return err
		}
	}

	return nil
}

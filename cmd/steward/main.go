package main

import (
	"context"
	"errors"
	"log/slog"
	"os"

	"github.com/urfave/cli/v3"
)

var ErrExit = errors.New("exit code")

func main() {
	slog.SetLogLoggerLevel(slog.LevelDebug)

	cmd := &cli.Command{
		Commands: []*cli.Command{
			{
				Name:      "index",
				Action:    IndexAction,
				Usage:     "recursively index all media in a directory",
				ArgsUsage: "<directory> [directory, ...]",
			},
			{
				Name:      "diff",
				Action:    DiffAction,
				Usage:     "diff two indexes",
				ArgsUsage: "<local index> <remote index>",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "local",
					},
					&cli.StringArg{
						Name: "remote",
					},
				},
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:  "output",
						Usage: "", // TODO: local-only, remote-only, identical, diff
						Value: "diff",
					},
				},
			},
			{
				Name:   "render",
				Action: RenderAction,
				Usage:  "render an HTML report of an index",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index", // TODO: read from stdin otherwise
					},
				},
			},
			{
				Name:      "upload",
				Action:    UploadAction,
				Usage:     "upload files",
				ArgsUsage: "[index]",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index",
					},
				},
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "from",
						Required: true,
					},
					&cli.StringFlag{
						Name:     "to",
						Required: true,
					},
					&cli.BoolFlag{
						Name: "force",
					},
				},
			},
			{
				Name:      "download",
				Usage:     "download files",
				Action:    DownloadAction,
				ArgsUsage: "[index]",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index",
					},
				},
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "from",
						Required: true,
					},
					&cli.StringFlag{
						Name:     "to",
						Required: true,
					},
					&cli.BoolFlag{
						Name: "force",
					},
				},
			},
		},
	}

	err := cmd.Run(context.Background(), os.Args)
	if err == ErrExit {
		os.Exit(1)
	} else if err != nil {
		slog.Error("Fatal error", slog.Any("error", err))
		os.Exit(1)
	}
}

package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"

	"github.com/urfave/cli/v3"
)

var _ error = (*ErrExit)(nil)

type ErrExit struct {
	Code int
}

func (e ErrExit) Error() string {
	return fmt.Sprintf("exit code: %d", e.Code)
}

func ExitErrorf(code int, format string, a ...any) error {
	return errors.Join(ErrExit{Code: code}, fmt.Errorf(format, a...))
}

const (
	ExitCodeIndex      = 64
	ExitCodeDuplicates = 66
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelWarn})))
	cmd := &cli.Command{
		Usage:       "Index, diff, backup and replicate large FLAC libraries",
		Description: "Steward lets you index, diff, backup and replicate large FLAC libraries.",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name: "verbose",
			},
		},
		Before: func(ctx context.Context, c *cli.Command) (context.Context, error) {
			if c.Bool("verbose") {
				slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug})))
			}

			return ctx, nil
		},
		Commands: []*cli.Command{
			{
				Name:      "index",
				Action:    IndexAction,
				Usage:     "Recursively indexes all media in one or more directories",
				ArgsUsage: "<directory> [directory, ...]",
			},
			{
				Name:      "diff",
				Action:    DiffAction,
				Usage:     "Diffs two indexes",
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
				Name:      "lint",
				Action:    LintAction,
				Usage:     "Lint an index",
				ArgsUsage: "[index]",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index",
					},
				},
			},
			{
				Name:   "render",
				Action: RenderAction,
				Usage:  "Renders an HTML report of an index",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index", // TODO: read from stdin otherwise
					},
				},
			},
			{
				Name:      "upload",
				Action:    UploadAction,
				Usage:     "Uploads to a remote",
				ArgsUsage: "[index]",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index",
					},
				},
				DisableSliceFlagSeparator: true,
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "from",
						Required: true,
					},
					&cli.StringFlag{
						Name:     "to",
						Required: true,
					},
					&cli.StringSliceFlag{
						Name:  "tag",
						Usage: "Upload the index with a named tag. Can be specified more than once. Can tag by path by specifying <path>:<tag>",
					},
					&cli.BoolFlag{
						Name: "force",
					},
					&cli.IntFlag{
						Name:  "parallelism",
						Usage: "Number of parallel uploads. Keep low if all files are on the same disk or if using fast storage",
						Value: 3,
					},
				},
			},
			{
				Name:      "upload-index",
				Action:    UploadIndexAction,
				Usage:     "Uploads an index",
				ArgsUsage: "[index]",
				Arguments: []cli.Argument{
					&cli.StringArg{
						Name: "index",
					},
				},
				DisableSliceFlagSeparator: true,
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "to",
						Required: true,
					},
					&cli.StringFlag{
						Name:  "tag",
						Usage: "Named tag",
					},
				},
			},
			{
				Name:      "download",
				Usage:     "Downloads files in an index from a remote",
				Action:    DownloadAction,
				ArgsUsage: "<index>",
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
					&cli.IntFlag{
						Name:  "parallelism",
						Usage: "Number of parallel downloads. Keep low if all files are on the same disk or if using fast storage",
						Value: 3,
					},
				},
			},
			{
				Name:      "download-index",
				Usage:     "Downloads an index by id",
				Action:    DownloadIndexAction,
				ArgsUsage: "<index id>",
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
				},
			},
		},
	}

	err := cmd.Run(context.Background(), os.Args)
	if e, ok := errors.AsType[ErrExit](err); ok {
		if e != err {
			fmt.Println(err.Error())
		}
		os.Exit(e.Code)
	} else if err != nil {
		slog.Error("Fatal error", slog.Any("error", err))
		os.Exit(1)
	}
}

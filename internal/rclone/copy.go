package rclone

import (
	"context"

	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/operations"
)

func Copy(ctx context.Context, source fs.Fs, path string, destination fs.Fs, destinationPath string) error {
	return operations.CopyFile(ctx, destination, source, destinationPath, path)
}

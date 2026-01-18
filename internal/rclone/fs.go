package rclone

import (
	"context"
	"fmt"

	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/cache"
	"github.com/rclone/rclone/fs/config/configfile"
	"github.com/rclone/rclone/fs/hash"

	_ "github.com/rclone/rclone/backend/b2"
	_ "github.com/rclone/rclone/backend/local"
)

func init() {
	configfile.Install()
}

func GetFS(ctx context.Context, remoteName string) (fs.Fs, error) {
	f, err := cache.Get(ctx, remoteName)
	if err != nil {
		return nil, err
	}

	if !f.Hashes().Contains(hash.SHA1) {
		return nil, fmt.Errorf("unsupported file system")
	}

	cache.Pin(f)

	return f, nil
}

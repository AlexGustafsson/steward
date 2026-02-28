package rclone

import (
	"path/filepath"
	"strings"
	"time"
)

type Entry struct {
	Name        string
	ModTime     time.Time
	Size        int64
	Metadata    []string
	AudioDigest string
}

func (e Entry) BlobName() string {
	algorithm, digest, _ := strings.Cut(e.AudioDigest, ":")
	return filepath.Join("blobs", algorithm, digest)
}

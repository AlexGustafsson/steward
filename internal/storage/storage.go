package storage

import (
	"context"
	"io"
	"time"
)

type BlobInfo struct {
	Digest       string
	LastModified time.Time
	Size         int64
}

type BlobStorage interface {
	GetBlobs(ctx context.Context) (map[string]BlobInfo, error)
	PutBlob(ctx context.Context, key string, r io.Reader, digest string, size int64) error
	GetBlob(ctx context.Context, key string) (io.ReadCloser, string, error)
}

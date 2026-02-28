package storage

import (
	"context"
	"io"
	"time"
)

type Storage interface {
	Put(context.Context) error
	Get(context.Context) error
}

type BlobInfo struct {
	Digest       string
	LastModified time.Time
	Size         int64
}

type BlobStorage interface {
	GetBlobs(ctx context.Context) (map[string]BlobInfo, error)
	PutBlob(ctx context.Context, key string, r io.Reader, digest string) error
	GetBlob(ctx context.Context, key string) (io.ReadCloser, string, error)
}

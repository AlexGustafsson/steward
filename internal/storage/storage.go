package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"time"
)

type ReadAtSeeker interface {
	io.ReadSeeker
	io.ReaderAt
}

type BlobInfo struct {
	Digest       string
	LastModified time.Time
	Size         int64
}

type BlobStorage interface {
	GetBlobs(ctx context.Context) (map[string]BlobInfo, error)
	PutBlob(ctx context.Context, key string, r ReadAtSeeker, digest string, size int64) error
	GetBlob(ctx context.Context, key string) (io.ReadCloser, string, error)
}

func NewBlobStorage(bucket string) (BlobStorage, error) {
	// For now, check only Backblaze
	{
		region := os.Getenv("B2_REGION")
		key := os.Getenv("B2_KEY")
		secret := os.Getenv("B2_SECRET")

		if region != "" && key != "" && secret != "" {
			return NewS3Storage(region, BackBlazeS3Endpoint(region), key, secret, "", bucket), nil
		}
	}

	return nil, fmt.Errorf("no blob storage configured")
}

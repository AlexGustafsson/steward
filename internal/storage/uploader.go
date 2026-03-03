package storage

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

type Uploader struct {
	UploadedBytes  atomic.Uint64
	ProcessedBytes atomic.Uint64
	Failures       atomic.Uint64
	Successes      atomic.Uint64

	blobs  map[string]BlobInfo
	remote BlobStorage
	local  *os.Root
}

func NewUploader(ctx context.Context, remote BlobStorage, basePath string) (*Uploader, error) {
	blobs, err := remote.GetBlobs(ctx)
	if err != nil {
		return nil, err
	}

	root, err := os.OpenRoot(basePath)
	if err != nil {
		return nil, err
	}

	return &Uploader{
		blobs:  blobs,
		remote: remote,
		local:  root,
	}, nil
}

func (u *Uploader) Upload(ctx context.Context, entry indexing.Entry, force bool) error {
	logger := slog.With(slog.String("indexName", entry.Name), slog.String("audioDigest", entry.AudioDigest))

	nameInRoot, err := filepath.Rel(u.local.Name(), entry.Name)
	if err != nil {
		return err
	}

	audioDigestAlgorithm, audioDigest, _ := strings.Cut(entry.AudioDigest, ":")
	blobKey := filepath.Join("blobs", audioDigestAlgorithm, audioDigest)

	blobEntry, blobEntryExists := u.blobs[blobKey]
	if blobEntryExists {
		if force {
			logger.Debug("Remote already has matching blob name but force enabled - uploading")
		} else {
			logger.Debug("Remote already has matching blob name - skipping")
			u.ProcessedBytes.Add(uint64(entry.Size))
			return nil
		}
	} else {
		logger.Debug("Local file missing in remote - uploading")
	}

	file, err := u.local.Open(nameInRoot)
	if err != nil {
		u.Failures.Add(1)
		return err
	}
	defer file.Close()

	md5sum := md5.New()

	fileSize, err := io.Copy(md5sum, file)
	if err != nil {
		u.Failures.Add(1)
		return err
	}

	_, err = file.Seek(0, 0)
	if err != nil {
		u.Failures.Add(1)
		return err
	}

	fileDigest := "md5:" + hex.EncodeToString(md5sum.Sum(nil))

	if blobEntryExists && blobEntry.Digest == fileDigest {
		logger.Debug("Remote blob matches local file - skipping upload")
		file.Close()
		u.ProcessedBytes.Add(uint64(entry.Size))
		return nil
	}

	err = u.remote.PutBlob(ctx, blobKey, newStatsReader(file, &u.UploadedBytes), fileDigest, fileSize)
	u.ProcessedBytes.Add(uint64(entry.Size))
	if err != nil {
		u.Failures.Add(1)
		return err
	}

	u.Successes.Add(1)
	return nil
}

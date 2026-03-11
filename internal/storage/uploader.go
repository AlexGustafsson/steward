package storage

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"io"
	"log/slog"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"
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

	mutex             sync.Mutex
	successfulEntries []indexing.Entry
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
	blobKey := path.Join("blobs", audioDigestAlgorithm, audioDigest)

	blobEntry, blobEntryExists := u.blobs[blobKey]
	if blobEntryExists {
		if force {
			logger.Debug("Remote already has matching blob name but force enabled - uploading")
		} else {
			logger.Debug("Remote already has matching blob name - skipping")
			u.ProcessedBytes.Add(uint64(entry.Size))
			u.successfulEntries = append(u.successfulEntries, entry)
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
		u.successfulEntries = append(u.successfulEntries, entry)
		return nil
	}

	err = u.remote.PutBlob(ctx, blobKey, newStatsReader(file, &u.UploadedBytes), fileDigest, fileSize)
	u.ProcessedBytes.Add(uint64(entry.Size))
	if err != nil {
		u.Failures.Add(1)
		return err
	}

	u.Successes.Add(1)
	u.mutex.Lock()
	defer u.mutex.Unlock()
	u.successfulEntries = append(u.successfulEntries, entry)
	return nil
}

func (u *Uploader) UploadIndex(ctx context.Context, pathPrefix string, label string) (string, error) {
	u.mutex.Lock()
	defer u.mutex.Unlock()

	var buffer bytes.Buffer

	md5 := md5.New()
	gzipWriter := gzip.NewWriter(io.MultiWriter(&buffer, md5))
	encoder := json.NewEncoder(gzipWriter)
	for _, entry := range u.successfulEntries {
		if pathPrefix != "" && !strings.HasPrefix(entry.Name, pathPrefix) {
			continue
		}

		err := encoder.Encode(&entry)
		if err != nil {
			return "", err
		}
	}
	if err := gzipWriter.Close(); err != nil {
		return "", err
	}

	md5sum := hex.EncodeToString(md5.Sum(nil))

	fileDigest := "md5:" + md5sum

	// By default, the key is just the first few characters of the md5sum as the
	// whole point of the indexes is to simplify for humans referencing to it
	namespace := "md5"
	id := md5sum[0:5]
	if label != "" {
		namespace = "_"
		id = label
	}
	key := path.Join("index", namespace, id)

	err := u.remote.PutBlob(ctx, key, &buffer, fileDigest, int64(buffer.Len()))
	if err != nil {
		return "", err
	}

	return namespace + ":" + id, nil
}

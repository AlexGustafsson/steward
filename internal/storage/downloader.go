package storage

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

type FileNameFunc func(indexing.Entry) string

type Downloader struct {
	DownloadedBytes atomic.Uint64
	ProcessedBytes  atomic.Uint64
	Failures        atomic.Uint64
	Successes       atomic.Uint64

	// FileNameFunc optionally specifies a file name generator.
	// Defaults to [FileNameFunc].
	FileNameFunc FileNameFunc

	blobs  map[string]BlobInfo
	remote BlobStorage
	local  *os.Root
	force  bool
}

func NewDownloader(ctx context.Context, remote BlobStorage, basePath string, force bool) (*Downloader, error) {
	if force {
		err := os.MkdirAll(basePath, os.ModePerm)
		if err != nil {
			return nil, err
		}
	}

	entries, err := os.ReadDir(basePath)
	if err != nil {
		return nil, err
	}

	if len(entries) > 0 && !force {
		return nil, fmt.Errorf("expected empty download directory when force is disabled")
	}

	root, err := os.OpenRoot(basePath)
	if err != nil {
		return nil, err
	}

	blobs, err := remote.GetBlobs(ctx)
	if err != nil {
		root.Close()
		return nil, err
	}

	return &Downloader{
		blobs:  blobs,
		remote: remote,
		local:  root,
		force:  force,
	}, nil
}

func (d *Downloader) Download(ctx context.Context, entry indexing.Entry) error {
	logger := slog.With(slog.String("indexName", entry.Name), slog.String("audioDigest", entry.AudioDigest))

	audioDigestAlgorithm, audioDigest, _ := strings.Cut(entry.AudioDigest, ":")
	blobKey := filepath.Join("blobs", audioDigestAlgorithm, audioDigest)

	blobEntry, blobEntryExists := d.blobs[blobKey]
	if !blobEntryExists {
		d.Failures.Add(1)
		return fmt.Errorf("indexed file does not exist in remote storage")
	}

	fileNameFunc := d.FileNameFunc
	if fileNameFunc == nil {
		fileNameFunc = DefaultFileNameFunc
	}

	name := filepath.Join(fileNameFunc(entry))
	logger = logger.With(slog.String("localName", name))

	err := d.local.MkdirAll(filepath.Dir(name), os.ModePerm)
	if err != nil {
		d.Failures.Add(1)
		return err
	}

	fileExists := true
	file, err := d.local.OpenFile(name, os.O_RDWR, 0644)
	if errors.Is(err, os.ErrNotExist) {
		fileExists = false
		file, err = d.local.OpenFile(name, os.O_WRONLY|os.O_CREATE, 0644)
	}
	if err != nil {
		d.Failures.Add(1)
		return err
	}
	defer file.Close()

	if fileExists {
		if d.force {
			slog.Debug("Local file name already exists but force enabled - downloading")

			md5sum := md5.New()

			_, err = io.Copy(md5sum, file)
			if err != nil {
				d.Failures.Add(1)
				return err
			}

			_, err = file.Seek(0, 0)
			if err != nil {
				d.Failures.Add(1)
				return err
			}

			fileDigest := "md5:" + hex.EncodeToString(md5sum.Sum(nil))

			if blobEntry.Digest == fileDigest {
				slog.Debug("Local file matches remote - skipping")
				return nil
			}
		} else {
			slog.Debug("Local file name already exists - skipping")
			return nil
		}
	}

	blob, expectedDigest, err := d.remote.GetBlob(ctx, blobKey)
	if err != nil {
		return err
	}
	defer blob.Close()

	md5sum := md5.New()

	n, err := io.Copy(io.MultiWriter(file, md5sum), newStatsReader(blob, &d.DownloadedBytes))
	d.ProcessedBytes.Add(uint64(n))
	if err != nil {
		d.Failures.Add(1)
		return err
	}

	actualDigest := "md5:" + hex.EncodeToString(md5sum.Sum(nil))
	if actualDigest != expectedDigest {
		logger.Warn("Downloaded file digest does not match remote")
	}

	err = d.local.Chtimes(name, time.Now(), entry.ModTime)
	if err != nil {
		logger.Warn("Failed to change modtime of downloaded file", slog.Any("error", err))
		// Fallthrough
	}

	d.Successes.Add(1)
	return nil
}

func DefaultFileNameFunc(entry indexing.Entry) string {
	albumArtists := make([]string, 0)
	artist := ""
	artists := make([]string, 0)
	album := ""
	trackNumber := ""
	discNumber := ""
	discTotal := 0

	for _, e := range entry.Metadata {
		k, v, ok := strings.Cut(e, "=")
		if !ok {
			continue
		}

		switch k {
		case "ALBUMARTIST":
			albumArtists = append(albumArtists, v)
		case "ARTIST":
			artist = v
		case "ARTISTS":
			artists = append(artists, v)
		case "ALBUM":
			album = v
		case "TRACKNUMBER":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				trackNumber = fmt.Sprintf("%02d", n)
			}
		case "DISCNUMBER":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				discNumber = fmt.Sprintf("%02d", n)
			}
		case "DISCTOTAL":
			n, err := strconv.ParseInt(strings.TrimLeft(v, "0"), 10, 32)
			if err == nil {
				discTotal = int(n)
			}
		}
	}

	path := ""

	if len(albumArtists) > 0 {
		path = strings.Join(albumArtists, " ")
	} else if artist != "" {
		path = artist
	} else if len(artists) > 0 {
		path = strings.Join(artists, " ")
	}

	if album != "" {
		if path == "" {
			path = album
		} else {
			path = filepath.Join(path, album)
		}
	}

	path = filepath.Join(path, "Track ")

	if trackNumber == "" {
		path += entry.AudioDigest
	} else {
		path += trackNumber
	}

	if discTotal > 1 && discNumber != "" {
		path += "(CD " + discNumber + ")"
	}

	path += ".flac"

	return path
}

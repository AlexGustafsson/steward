package rclone

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/hash"
)

var _ fs.Fs = (*DiffFS)(nil)

type DiffFS struct {
	Entry Entry
}

// Features implements fs.Fs.
func (i *DiffFS) Features() *fs.Features {
	return &fs.Features{
		IsLocal: true,
	}
}

// Hashes implements fs.Fs.
func (i *DiffFS) Hashes() hash.Set {
	// B2 supports SHA-1 natively, for now use that
	return hash.NewHashSet(hash.SHA1)
}

// List implements fs.Fs.
func (i *DiffFS) List(ctx context.Context, dir string) (entries fs.DirEntries, err error) {
	panic("unimplemented")
}

// Mkdir implements fs.Fs.
func (i *DiffFS) Mkdir(ctx context.Context, dir string) error {
	panic("unimplemented")
}

// Name implements fs.Fs.
func (i *DiffFS) Name() string {
	return "difffs"
}

// NewObject implements fs.Fs.
func (i *DiffFS) NewObject(ctx context.Context, remote string) (fs.Object, error) {
	// TODO: Use blob name?
	if i.Entry.Name == remote {
		return &DiffObject{
			fs:    i,
			entry: i.Entry,
		}, nil
	}

	return nil, fs.ErrorObjectNotFound
}

// Precision implements fs.Fs.
func (i *DiffFS) Precision() time.Duration {
	return time.Nanosecond
}

// Put implements fs.Fs.
func (i *DiffFS) Put(ctx context.Context, in io.Reader, src fs.ObjectInfo, options ...fs.OpenOption) (fs.Object, error) {
	file, err := os.CreateTemp("", "steward-rand-*")
	if err != nil {
		return nil, err
	}

	_, err = io.Copy(file, in)
	if err != nil {
		return nil, err
	}

	_, err = file.Seek(0, 0)
	if err != nil {
		return nil, err
	}

	// TODO: Support setting modtime

	// TODO: This will hash the audio data, might be unnecessary? Probably fast
	// enough for us to ignore for now to keep code small and dump
	entry, err := indexing.IndexFile(file.Name(), file)
	if err != nil {
		return nil, err
	}

	err = file.Close()
	if err != nil {
		return nil, err
	}

	path := filepath.Join(src.Remote(), FileName(entry))

	err = os.MkdirAll(filepath.Dir(path), os.ModePerm)
	if err != nil {
		return nil, err
	}

	// TODO: Deal with duplicate names
	err = os.Rename(file.Name(), path)
	if err != nil {
		return nil, err
	}

	return &DiffObject{
		fs: i,
		entry: Entry{
			Name:        entry.Name,
			ModTime:     entry.ModTime,
			Size:        entry.Size,
			Metadata:    entry.Metadata,
			AudioDigest: entry.AudioDigest,
			FileDigest:  entry.FileDigest,
		},
	}, nil
}

// Rmdir implements fs.Fs.
func (i *DiffFS) Rmdir(ctx context.Context, dir string) error {
	panic("unimplemented")
}

// Root implements fs.Fs.
func (i *DiffFS) Root() string {
	return ""
}

// String implements fs.Fs.
func (i *DiffFS) String() string {
	return ""
}

var _ fs.Object = (*DiffObject)(nil)
var _ fs.MimeTyper = (*DiffObject)(nil)

type DiffObject struct {
	fs    fs.Fs
	entry Entry
}

func (b *DiffObject) Entry() Entry {
	return b.entry
}

// SetModTime implements fs.Object.
func (b *DiffObject) SetModTime(ctx context.Context, t time.Time) error {
	panic("unimplemented")
}

// Update implements fs.Object.
func (b *DiffObject) Update(ctx context.Context, in io.Reader, src fs.ObjectInfo, options ...fs.OpenOption) error {
	panic("unimplemented")
}

// Fs implements fs.ObjectInfo.
func (b *DiffObject) Fs() fs.Info {
	return b.fs
}

// Hash implements fs.ObjectInfo.
func (b *DiffObject) Hash(ctx context.Context, ty hash.Type) (string, error) {
	if ty != hash.SHA1 {
		return "", nil
	}

	// Trim leading "sha1-" prefix
	return b.entry.FileDigest[5:], nil
}

// ModTime implements fs.ObjectInfo.
func (b *DiffObject) ModTime(context.Context) time.Time {
	return b.entry.ModTime
}

// Remote implements fs.ObjectInfo.
func (b *DiffObject) Remote() string {
	return b.entry.Name
}

// Size implements fs.ObjectInfo.
func (b *DiffObject) Size() int64 {
	return b.entry.Size
}

// Storable implements fs.ObjectInfo.
func (b *DiffObject) Storable() bool {
	return true
}

// String implements fs.ObjectInfo.
func (b *DiffObject) String() string {
	return b.entry.Name
}

// MimeType implements fs.MimeTyper.
func (b *DiffObject) MimeType(ctx context.Context) string {
	panic("unimplemented")
}

func (b *DiffObject) Open(ctx context.Context, options ...fs.OpenOption) (io.ReadCloser, error) {
	// TODO: Temp file, then move
	return os.Open(b.entry.Name)
}

func (b *DiffObject) Remove(ctx context.Context) error {
	panic("unimplemented")
}

func FileName(entry indexing.Entry) string {
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

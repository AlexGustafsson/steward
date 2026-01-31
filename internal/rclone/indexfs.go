package rclone

import (
	"context"
	"io"
	"os"
	"time"

	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/hash"
)

var _ fs.Fs = (*IndexFS)(nil)

type IndexFS struct {
	Entry Entry
}

// Features implements fs.Fs.
func (i *IndexFS) Features() *fs.Features {
	return &fs.Features{
		IsLocal: true,
	}
}

// Hashes implements fs.Fs.
func (i *IndexFS) Hashes() hash.Set {
	// B2 supports SHA-1 natively, for now use that
	return hash.NewHashSet(hash.SHA1)
}

// List implements fs.Fs.
func (i *IndexFS) List(ctx context.Context, dir string) (entries fs.DirEntries, err error) {
	panic("unimplemented")
}

// Mkdir implements fs.Fs.
func (i *IndexFS) Mkdir(ctx context.Context, dir string) error {
	panic("unimplemented")
}

// Name implements fs.Fs.
func (i *IndexFS) Name() string {
	return "indexfs"
}

// NewObject implements fs.Fs.
func (i *IndexFS) NewObject(ctx context.Context, remote string) (fs.Object, error) {
	// TODO: Use blob name?
	if i.Entry.Name == remote {
		return &IndexObject{
			fs:    i,
			entry: i.Entry,
			// Assumed
			mimeType: "audio/flac",
		}, nil
	}

	return nil, fs.ErrorObjectNotFound
}

// Precision implements fs.Fs.
func (i *IndexFS) Precision() time.Duration {
	return time.Nanosecond
}

// Put implements fs.Fs.
func (i *IndexFS) Put(ctx context.Context, in io.Reader, src fs.ObjectInfo, options ...fs.OpenOption) (fs.Object, error) {
	panic("unimplemented")
}

// Rmdir implements fs.Fs.
func (i *IndexFS) Rmdir(ctx context.Context, dir string) error {
	panic("unimplemented")
}

// Root implements fs.Fs.
func (i *IndexFS) Root() string {
	return ""
}

// String implements fs.Fs.
func (i *IndexFS) String() string {
	return ""
}

type Object struct{}

var _ fs.Object = (*IndexObject)(nil)
var _ fs.MimeTyper = (*IndexObject)(nil)

type IndexObject struct {
	fs       fs.Fs
	entry    Entry
	mimeType string
}

func (b *IndexObject) Entry() Entry {
	return b.entry
}

// SetModTime implements fs.Object.
func (b *IndexObject) SetModTime(ctx context.Context, t time.Time) error {
	panic("unimplemented")
}

// Update implements fs.Object.
func (b *IndexObject) Update(ctx context.Context, in io.Reader, src fs.ObjectInfo, options ...fs.OpenOption) error {
	panic("unimplemented")
}

// Fs implements fs.ObjectInfo.
func (b *IndexObject) Fs() fs.Info {
	return b.fs
}

// Hash implements fs.ObjectInfo.
func (b *IndexObject) Hash(ctx context.Context, ty hash.Type) (string, error) {
	if ty != hash.SHA1 {
		return "", nil
	}

	// Trim leading "sha1-" prefix
	return b.entry.FileDigest[5:], nil
}

// ModTime implements fs.ObjectInfo.
func (b *IndexObject) ModTime(context.Context) time.Time {
	return b.entry.ModTime
}

// Remote implements fs.ObjectInfo.
func (b *IndexObject) Remote() string {
	return b.entry.Name
}

// Size implements fs.ObjectInfo.
func (b *IndexObject) Size() int64 {
	return b.entry.Size
}

// Storable implements fs.ObjectInfo.
func (b *IndexObject) Storable() bool {
	return true
}

// String implements fs.ObjectInfo.
func (b *IndexObject) String() string {
	return b.entry.Name
}

// MimeType implements fs.MimeTyper.
func (b *IndexObject) MimeType(ctx context.Context) string {
	return b.mimeType
}

func (b *IndexObject) Open(ctx context.Context, options ...fs.OpenOption) (io.ReadCloser, error) {
	return os.Open(b.entry.Name)
}

func (b *IndexObject) Remove(ctx context.Context) error {
	panic("unimplemented")
}

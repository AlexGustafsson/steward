package storage

import (
	"io"
	"sync/atomic"
)

var _ io.Reader = (*reader)(nil)

type reader struct {
	bytes *atomic.Uint64
	r     io.Reader
}

// Read implements [io.ReadCloser].
func (r reader) Read(p []byte) (n int, err error) {
	n, err = r.r.Read(p)
	r.bytes.Add(uint64(n))
	return n, err
}

func newStatsReader(r io.Reader, bytes *atomic.Uint64) io.Reader {
	return reader{bytes: bytes, r: r}
}

var _ ReadAtSeeker = (*readatseeker)(nil)

type readatseeker struct {
	bytes *atomic.Uint64
	r     ReadAtSeeker
}

// Read implements [ReadAtSeeker].
func (r readatseeker) Read(p []byte) (n int, err error) {
	n, err = r.r.Read(p)
	r.bytes.Add(uint64(n))
	return n, err
}

// ReadAt implements [ReadAtSeeker].
func (r readatseeker) ReadAt(p []byte, off int64) (n int, err error) {
	n, err = r.r.ReadAt(p, off)
	r.bytes.Add(uint64(n))
	return n, err
}

// Seek implements [ReadAtSeeker].
func (r readatseeker) Seek(offset int64, whence int) (int64, error) {
	return r.r.Seek(offset, whence)
}

func newStatsReaderAtSeeker(r ReadAtSeeker, bytes *atomic.Uint64) ReadAtSeeker {
	return readatseeker{bytes: bytes, r: r}
}

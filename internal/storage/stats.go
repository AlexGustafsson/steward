package storage

import (
	"io"
	"sync/atomic"
)

var _ io.ReadCloser = (*reader)(nil)

type reader struct {
	bytes *atomic.Uint64
	r     io.ReadCloser
}

// Close implements [io.ReadCloser].
func (r reader) Close() error {
	return r.r.Close()
}

// Read implements [io.ReadCloser].
func (r reader) Read(p []byte) (n int, err error) {
	n, err = r.r.Read(p)
	r.bytes.Add(uint64(n))
	return n, err
}

func newStatsReader(r io.Reader, bytes *atomic.Uint64) io.Reader {
	return reader{bytes: bytes, r: io.NopCloser(r)}
}

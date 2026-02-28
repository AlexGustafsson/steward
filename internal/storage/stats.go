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

type ReadStats struct {
	Bytes atomic.Uint64
}

func (s *ReadStats) NewReader(r io.Reader) io.Reader {
	return reader{bytes: &s.Bytes, r: io.NopCloser(r)}
}

func (s *ReadStats) NewReadCloser(r io.ReadCloser) io.Reader {
	return reader{bytes: &s.Bytes, r: r}
}

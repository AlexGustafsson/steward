package flac

import (
	"bufio"
	"errors"
	"io"
)

var Magic = [4]byte{'f', 'L', 'a', 'C'}

type FileReader struct {
	reader     *bufio.Reader
	expectMeta bool
	eof        bool
}

func NewFileReader(r io.Reader) (*FileReader, error) {
	reader := bufio.NewReader(r)

	// Read file magic
	var magic [4]byte
	_, err := io.ReadFull(reader, magic[:])
	if err != nil {
		return nil, err
	}

	return &FileReader{
		reader:     reader,
		expectMeta: true,
	}, nil
}

func (r *FileReader) NextReader() (io.Reader, int, error) {
	if r.expectMeta {
		header, err := r.reader.Peek(4)
		if errors.Is(err, io.EOF) {
			return nil, -1, io.ErrUnexpectedEOF
		} else if err != nil {
			return nil, -1, err
		}

		moreMeta := header[0]&0x80 == 0
		if !moreMeta {
			r.expectMeta = false
		}

		size := int64(header[1])<<16 | int64(header[2])<<8 | int64(header[3])

		return io.LimitReader(r.reader, 4+size), int(header[0] & 0x7F), nil
	} else if !r.eof {
		r.eof = true
		return r.reader, -1, nil
	}

	return nil, -1, io.EOF
}

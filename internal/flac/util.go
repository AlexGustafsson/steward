package flac

import (
	"errors"
	"io"
)

func Copy(w io.Writer, r io.Reader, metadata []string) (int, error) {
	reader, err := NewFileReader(r)
	if err != nil {
		return 0, err
	}

	written, err := w.Write(Magic[:])
	if err != nil {
		return 0, err
	}

	for {
		reader, metadataBlockType, err := reader.NextReader()
		if errors.Is(err, io.EOF) {
			break
		} else if err != nil {
			return written, err
		}

		switch metadataBlockType {
		case 4:
			// TODO: Assumes there is a metadata block already and that there's only
			// one
			existingComment, err := ReadVorbisComment(reader)
			if err != nil {
				return written, err
			}

			newComment := &VorbisComment{
				VendorString: existingComment.VendorString,
				Fields:       make([][]byte, len(metadata)),
			}

			for i, m := range metadata {
				newComment.Fields[i] = []byte(m)
			}

			n, err := WriteVorbisComment(w, newComment)
			if err != nil {
				return written, err
			}

			written += n
		default:
			n, err := io.Copy(w, reader)
			if err != nil {
				return written, err
			}

			written += int(n)
		}
	}

	return written, nil
}

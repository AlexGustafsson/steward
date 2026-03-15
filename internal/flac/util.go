package flac

import (
	"bytes"
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
			existingCommentBytes, err := io.ReadAll(reader)
			if err != nil {
				return written, err
			}

			existingComment, err := ReadVorbisComment(bytes.NewReader(existingCommentBytes))
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

			// Diff, as to keep order (and thus file digest) from the remoet file.
			// Ensures that, if the metadata is the same, the resulting file digest is
			// the same. Not doing this would likely result in different file digests
			// when force downloading as the index is always sorted, but rarely the
			// files
			commentsMatch := len(existingComment.Fields) == len(newComment.Fields)
			if commentsMatch {
				for i := 0; i < len(newComment.Fields); i++ {
					if !bytes.Equal(newComment.Fields[i], existingComment.Fields[i]) {
						commentsMatch = false
						break
					}
				}
			}

			if commentsMatch {
				n, err := w.Write(existingCommentBytes)
				if err != nil {
					return written, err
				}

				written += n
			} else {
				n, err := WriteVorbisComment(w, newComment)
				if err != nil {
					return written, err
				}

				written += n
			}
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

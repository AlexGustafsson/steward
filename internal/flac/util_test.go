package flac

import (
	"bytes"
	"errors"
	"io"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCopy(t *testing.T) {
	if testing.Short() {
		t.Skip()
	}

	file, err := os.Open("testdata/test.flac")
	require.NoError(t, err)

	expectedContents, err := io.ReadAll(file)
	require.NoError(t, file.Close())
	require.NoError(t, err)

	// Read the comment from the file
	var comment *VorbisComment
	{
		reader, err := NewFileReader(bytes.NewReader(expectedContents))
		require.NoError(t, err)

		for {
			r, metadataBlockType, err := reader.NextReader()
			if errors.Is(err, io.EOF) {
				break
			}
			require.NoError(t, err)

			if metadataBlockType != 4 {
				_, err := io.Copy(io.Discard, r)
				require.NoError(t, err)
				continue
			}

			c, err := ReadVorbisComment(r)
			require.NoError(t, err)
			comment = c
			break
		}
	}

	metadata := make([]string, len(comment.Fields))
	for i, f := range comment.Fields {
		metadata[i] = string(f)
	}

	// Copy the file, replacing the comment
	var actualContents bytes.Buffer
	n, err := Copy(&actualContents, bytes.NewReader(expectedContents), metadata)
	require.NoError(t, err)

	// Make sure the process is no different than whatever wrote the original file
	assert.Equal(t, n, actualContents.Len())
	assert.Equal(t, expectedContents, actualContents.Bytes())
}

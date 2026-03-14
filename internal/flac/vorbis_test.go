package flac

import (
	"bytes"
	"encoding/base64"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestVorbisComment(t *testing.T) {
	expectedString := `BAAA1yAAAAByZWZlcmVuY2UgbGliRkxBQyAxLjUuMCAyMDI1MDIxMQkAAAAOAAAAQVJUSVNUPUdl
bmVzaXMWAAAAQUxCVU09V2UgQ2Fu4oCZdCBEYW5jZRcAAABUSVRMRT1KZXN1cyBIZSBLbm93cyBN
ZQkAAABEQVRFPTE5OTEOAAAAVFJBQ0tOVU1CRVI9MDINAAAAVFJBQ0tUT1RBTD0xMg0AAABDRERC
PWFhMTBjOTBjFgAAAEdFTlJFPXByb2dyZXNzaXZlIHJvY2sJAAAAR0VOUkU9cG9w`

	expectedBytes, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(expectedString, "\n", ""))
	require.NoError(t, err)

	expectedComment := &VorbisComment{
		VendorString: "reference libFLAC 1.5.0 20250211",
		Fields: [][]byte{
			[]byte("ARTIST=Genesis"),
			[]byte("ALBUM=We Can’t Dance"),
			[]byte("TITLE=Jesus He Knows Me"),
			[]byte("DATE=1991"),
			[]byte("TRACKNUMBER=02"),
			[]byte("TRACKTOTAL=12"),
			[]byte("CDDB=aa10c90c"),
			[]byte("GENRE=progressive rock"),
			[]byte("GENRE=pop"),
		},
	}

	comment, err := ReadVorbisComment(bytes.NewReader(expectedBytes))
	require.NoError(t, err)
	assert.Equal(t, expectedComment, comment)

	var buffer bytes.Buffer
	n, err := WriteVorbisComment(&buffer, comment)
	require.NoError(t, err)
	assert.Equal(t, len(expectedBytes), n)
	assert.Equal(t, expectedBytes, buffer.Bytes())
}

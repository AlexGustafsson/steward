package flac

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDecoderDecode(t *testing.T) {
	if testing.Short() {
		t.Skip()
	}

	file, err := os.Open("testdata/test.flac")
	require.NoError(t, err)
	defer file.Close()

	reader, err := NewFileReader(file)
	require.NoError(t, err)

	for {
		r, metadataBlockType, err := reader.NextReader()
		if err == io.EOF {
			break
		}
		require.NoError(t, err)

		switch metadataBlockType {
		case 0:
			fmt.Println("Streaminfo")
			meta, err := io.ReadAll(r)
			require.NoError(t, err)
			xxd(meta)
			fmt.Println()
		case 1:
			fmt.Println("Padding")
			meta, err := io.ReadAll(r)
			require.NoError(t, err)
			xxd(meta)
			fmt.Println()
		case 2:
			fmt.Println("Application")
			meta, err := io.ReadAll(r)
			require.NoError(t, err)
			xxd(meta)
			fmt.Println()
		case 3:
			fmt.Println("Seek table")
			meta, err := io.ReadAll(r)
			require.NoError(t, err)
			xxd(meta)
			fmt.Println()
		case 4:
			fmt.Println("Vorbis comment")
			comment, err := ReadVorbisComment(r)
			require.NoError(t, err)
			fmt.Printf("Vendor: %s", comment.VendorString)
			for _, field := range comment.Fields {
				fmt.Printf("%s\n", field)
			}
		case 5:
			fmt.Println("Cuesheet")
			meta, err := io.ReadAll(r)
			require.NoError(t, err)
			xxd(meta)
			fmt.Println()
		case 6:
			fmt.Println("Picture")
			meta, err := io.ReadAll(r)
			require.NoError(t, err)
			xxd(meta)
			fmt.Println()
		case -1:
			hash := sha256.New()
			_, err = io.Copy(hash, r)
			require.NoError(t, err)

			fmt.Println("sha256:" + hex.EncodeToString(hash.Sum(nil)))
		default:
			fmt.Printf("Reserved: %d\n", metadataBlockType)
		}
	}
}

func xxd(message []byte) {
	stride := 16
	groupSize := 2
	groupExpression := regexp.MustCompile(fmt.Sprintf(`.{%d}`, groupSize+2))
	hexdumpWidth := (stride/groupSize)*(groupSize*2+1) - 1

	for offset := 0; offset < len(message); offset += stride {
		fmt.Printf("%08x: ", offset)

		slice := message[offset:min(offset+stride, len(message))]

		hex := hex.EncodeToString(slice)
		parts := groupExpression.FindAllString(hex, -1)
		fmt.Printf("%-*s", hexdumpWidth, strings.Join(parts, " "))

		fmt.Print(" ")

		for i := 0; i < len(slice); i++ {
			c := slice[i]
			if c >= 32 && c <= 127 {
				s := strings.TrimSpace(string(c))
				if s == "" {
					s = "."
				}
				fmt.Printf("%s", s)
			} else {
				fmt.Printf(".")
			}
		}

		fmt.Println()
	}
}

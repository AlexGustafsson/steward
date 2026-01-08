package flac

import (
	"encoding/binary"
	"fmt"
	"io"
)

type VorbisComment struct {
	VendorString string
	Fields       [][]byte
}

func ReadVorbisComment(r io.Reader) (*VorbisComment, error) {
	var header [4]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return nil, err
	}

	if header[0]&0x7F != 4 {
		return nil, fmt.Errorf("not a vorbis comment metadata block")
	}

	var vendorStringLength uint32
	if err := binary.Read(r, binary.LittleEndian, &vendorStringLength); err != nil {
		return nil, err
	}

	vendorString, err := io.ReadAll(io.LimitReader(r, int64(vendorStringLength)))
	if err != nil {
		return nil, err
	}

	var numberOfFields uint32
	if err := binary.Read(r, binary.LittleEndian, &numberOfFields); err != nil {
		return nil, err
	}

	fields := make([][]byte, numberOfFields)
	for i := range numberOfFields {
		var length uint32
		if err := binary.Read(r, binary.LittleEndian, &length); err != nil {
			return nil, err
		}

		value, err := io.ReadAll(io.LimitReader(r, int64(length)))
		if err != nil {
			return nil, err
		}

		fields[i] = value
	}

	return &VorbisComment{
		VendorString: string(vendorString),
		Fields:       fields,
	}, nil
}

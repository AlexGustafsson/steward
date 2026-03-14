package flac

import (
	"bytes"
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

	// TODO: Limit size to size from header

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

func WriteVorbisComment(w io.Writer, c *VorbisComment) (int, error) {
	var buffer bytes.Buffer

	err := binary.Write(&buffer, binary.LittleEndian, uint32(len(c.VendorString)))
	if err != nil {
		return 0, err
	}

	_, err = buffer.WriteString(c.VendorString)
	if err != nil {
		return 0, err
	}

	err = binary.Write(&buffer, binary.LittleEndian, uint32(len(c.Fields)))
	if err != nil {
		return 0, err
	}

	for _, f := range c.Fields {
		err := binary.Write(&buffer, binary.LittleEndian, uint32(len(f)))
		if err != nil {
			return 0, err
		}

		_, err = buffer.Write(f)
		if err != nil {
			return 0, err
		}
	}

	header := [4]byte{
		0x04, // TODO: We currently assume it's not the last block
		byte(buffer.Len() >> 16),
		byte(buffer.Len() >> 8),
		byte(buffer.Len() >> 0),
	}
	n1, err := w.Write(header[:])
	if err != nil {
		return n1, err
	}

	n2, err := io.Copy(w, &buffer)
	return n1 + int(n2), err
}

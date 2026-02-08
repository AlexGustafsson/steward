package report

import (
	"html/template"
	"io"
	"strings"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

type DiffData struct {
	EntriesA []DataEntry
	EntriesB []DataEntry
}

type IndexData struct {
	Title   string
	Entries []DataEntry
}

type DataEntry struct {
	FilePath      string
	FileDigest    string
	AudioDigest   string
	PictureDigest string

	ShortID     string
	Artist      string
	Album       string
	TrackNumber string
	Title       string
	Metadata    []MetadataEntry
}

func DataEntryFromIndexEntry(entry indexing.Entry) DataEntry {
	metadata := make([]MetadataEntry, 0)

	artist := ""
	album := ""
	trackNumber := ""
	title := ""

	// TODO: Just do some actual text diff and format it nicely?
	for _, v := range entry.Metadata {
		k, v, _ := strings.Cut(v, "=")

		metadata = append(metadata, MetadataEntry{
			Key:   k,
			Value: v,
		})

		switch k {
		case "ARTIST":
			artist = v
		case "ALBUM":
			album = v
		case "TRACKNUMBER":
			trackNumber = v
		case "TITLE":
			title = v
		}
	}

	// Treat picture digest as a meta metadata entry for diffing
	metadata = append(metadata, MetadataEntry{
		Key:   "[picture]",
		Value: entry.PictureDigest,
	})

	return DataEntry{
		FilePath:      entry.Name,
		FileDigest:    entry.FileDigest,
		AudioDigest:   entry.AudioDigest,
		PictureDigest: entry.PictureDigest,

		ShortID:     entry.AudioDigest[7:12],
		Artist:      artist,
		Album:       album,
		TrackNumber: trackNumber,
		Title:       title,
		Metadata:    metadata,
	}
}

type MetadataEntry struct {
	Key        string
	KeyClass   string
	Value      string
	ValueClass string
}

func RenderIndex(w io.Writer, title string, entries []DataEntry) error {
	t, err := template.ParseFS(templates, "templates/index.html.gotmpl")
	if err != nil {
		return err
	}

	return t.Execute(w, IndexData{
		Title:   title,
		Entries: entries,
	})
}

func RenderDiff(w io.Writer, entriesA []DataEntry, entriesB []DataEntry) error {
	t, err := template.ParseFS(templates, "templates/diff.html.gotmpl")
	if err != nil {
		return err
	}

	return t.Execute(w, DiffData{
		EntriesA: entriesA,
		EntriesB: entriesB,
	})
}

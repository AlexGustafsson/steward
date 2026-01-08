package report

import (
	"html/template"
	"io"
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
	ShortID     string
	Artist      string
	Album       string
	TrackNumber string
	Title       string
	FilePath    string
	Metadata    []MetadataEntry
	Digest      string
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

package main

import (
	"bufio"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

	"github.com/AlexGustafsson/steward/internal/report"
)

func diff(a string, b string) {
	entriesA, err := readEntries(a)
	if err != nil {
		panic(err)
	}

	entriesB, err := readEntries(b)
	if err != nil {
		panic(err)
	}

	onlyInA := make([]report.DataEntry, 0)
	onlyInB := make([]report.DataEntry, 0)
	inBoth := make([]report.DataEntry, 0)

	// TODO: Optimize if necessary
	for _, entryA := range entriesA {
		i, ok := slices.BinarySearchFunc(entriesB, entryA.Digest, func(entryB report.DataEntry, digest string) int {
			return strings.Compare(entryB.Digest, digest)
		})
		if ok {
			inBoth = append(inBoth, entryA, entriesB[i])
		} else {
			onlyInA = append(onlyInA, entryA)
		}
	}

	for _, entryB := range entriesB {
		_, ok := slices.BinarySearchFunc(entriesA, entryB.Digest, func(entryA report.DataEntry, digest string) int {
			return strings.Compare(entryA.Digest, digest)
		})
		if !ok {
			onlyInB = append(onlyInB, entryB)
		}
	}

	renderOnlyA(onlyInA)
	renderOnlyB(onlyInB)
	renderDiff(inBoth)
}

func renderOnlyA(entries []report.DataEntry) {
	file, err := os.CreateTemp("", "steward-only-a-*.html")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	if err := report.RenderIndex(file, "Yours", entries); err != nil {
		panic(err)
	}

	fmt.Println("Ours", file.Name())
	_ = exec.Command("open", file.Name()).Run()
}

func renderOnlyB(entries []report.DataEntry) {
	file, err := os.CreateTemp("", "steward-only-a-*.html")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	if err := report.RenderIndex(file, "Theirs", entries); err != nil {
		panic(err)
	}

	fmt.Println("Theirs", file.Name())
	_ = exec.Command("open", file.Name()).Run()
}

func renderDiff(entries []report.DataEntry) {
	entriesA := make([]report.DataEntry, 0)
	entriesB := make([]report.DataEntry, 0)

	// Entries are interleaved - A then B
	for i := 0; i < len(entries); i += 2 {
		entryA := entries[i]
		entryB := entries[i+1]

		entryA.Metadata, entryB.Metadata = diffMetadata(entryA.Metadata, entryB.Metadata)

		if len(entryA.Metadata) > 0 && len(entryB.Metadata) > 0 {
			entriesA = append(entriesA, entryA)
			entriesB = append(entriesB, entryB)
		}
	}

	file, err := os.CreateTemp("", "steward-diff-*.html")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	if err := report.RenderDiff(file, entriesA, entriesB); err != nil {
		panic(err)
	}

	fmt.Println("Diff", file.Name())
	_ = exec.Command("open", file.Name()).Run()
}

func diffMetadata(entriesA, entriesB []report.MetadataEntry) ([]report.MetadataEntry, []report.MetadataEntry) {
	outA := make([]report.MetadataEntry, 0)
	outB := make([]report.MetadataEntry, 0)

	// Assume entries are sorted, meaning we can loop through them both
	// simultaneously, "pausing" as necessary
	i := 0
	j := 0
	for i < len(entriesA) && j < len(entriesB) {
		a := entriesA[i]
		b := entriesB[j]

		switch strings.Compare(a.Key, b.Key) {
		case 0:
			if a.Value != b.Value {
				a.ValueClass = "diff"
				b.ValueClass = "diff"
				outA = append(outA, a)
				outB = append(outB, b)
			}

			i++
			j++
		case -1:
			a.KeyClass = "added"
			a.ValueClass = "added"

			outA = append(outA, a)

			outB = append(outB, report.MetadataEntry{
				Key:        a.Key,
				Value:      a.Value,
				KeyClass:   "removed",
				ValueClass: "removed",
			})

			i++
		case +1:
			b.KeyClass = "added"
			b.ValueClass = "added"

			outA = append(outA, report.MetadataEntry{
				Key:        b.Key,
				Value:      b.Value,
				KeyClass:   "removed",
				ValueClass: "removed",
			})

			outB = append(outB, b)

			j++
		}
	}

	// Drain remaining A
	for i < len(entriesA) {
		a := entriesA[i]
		a.KeyClass = "added"
		a.ValueClass = "added"

		outA = append(outA, a)

		outB = append(outB, report.MetadataEntry{
			Key:        a.Key,
			Value:      a.Value,
			KeyClass:   "removed",
			ValueClass: "removed",
		})

		i++
	}

	// Drain remaining B
	for j < len(entriesB) {
		b := entriesB[j]
		b.KeyClass = "added"
		b.ValueClass = "added"

		outA = append(outA, report.MetadataEntry{
			Key:        b.Key,
			Value:      b.Value,
			KeyClass:   "removed",
			ValueClass: "removed",
		})

		outB = append(outB, b)

		j++
	}

	return outA, outB
}

func readEntries(path string) ([]report.DataEntry, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader := io.Reader(file)
	if filepath.Ext(path) == ".gz" {
		var err error
		reader, err = gzip.NewReader(reader)
		if err != nil {
			return nil, err
		}
	}

	entries := make([]report.DataEntry, 0)

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		var entry Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			return nil, err
		}

		metadata := make([]report.MetadataEntry, 0)

		artist := ""
		album := ""
		trackNumber := ""
		title := ""

		// TODO: Just do some actual text diff and format it nicely?
		for _, v := range entry.Metadata {
			k, v, _ := strings.Cut(v, "=")

			metadata = append(metadata, report.MetadataEntry{
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

		entries = append(entries, report.DataEntry{
			ShortID:     entry.Digest[7:12],
			Artist:      artist,
			Album:       album,
			TrackNumber: trackNumber,
			Title:       title,
			FilePath:    entry.Path,
			Metadata:    metadata,
			Digest:      entry.Digest,
		})
	}

	slices.SortFunc(entries, func(a report.DataEntry, b report.DataEntry) int {
		return strings.Compare(a.Digest, b.Digest)
	})

	return entries, nil
}

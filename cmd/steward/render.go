package main

import (
	"context"
	"os"
	"os/exec"
	"strings"

	"github.com/AlexGustafsson/steward/internal/report"
	"github.com/urfave/cli/v3"
)

func RenderAction(ctx context.Context, cmd *cli.Command) error {
	return nil
}

func renderOnlyA(entries []report.DataEntry) error {
	file, err := os.CreateTemp("", "steward-only-a-*.html")
	if err != nil {
		return err
	}
	defer file.Close()

	if err := report.RenderIndex(file, "Only in local index", entries); err != nil {
		return err
	}

	return exec.Command("open", file.Name()).Run()
}

func renderOnlyB(entries []report.DataEntry) error {
	file, err := os.CreateTemp("", "steward-only-a-*.html")
	if err != nil {
		return err
	}
	defer file.Close()

	if err := report.RenderIndex(file, "Only in remote index", entries); err != nil {
		panic(err)
	}

	return exec.Command("open", file.Name()).Run()
}

func renderDiff(entries []report.DataEntry) error {
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
		return err
	}
	defer file.Close()

	if err := report.RenderDiff(file, entriesA, entriesB); err != nil {
		return err
	}

	return exec.Command("open", file.Name()).Run()
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

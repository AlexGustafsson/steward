package main

import (
	"log/slog"
	"os"
	"strings"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

// Complain on duplicates.
// TODO: Figure out what's sensible to do here.
func bailOnDuplicates(entries []indexing.Entry) {
	for _, entry := range entries {
		identical := make([]string, 0)
		for _, other := range entries {
			if entry.AudioDigest == other.AudioDigest {
				identical = append(identical, entry.Name)
			}
		}
		if len(identical) > 1 {
			slog.Error("There are duplicate songs (identical audio digest)", slog.String("paths", strings.Join(identical, ",")))
			os.Exit(1)
		}
	}
}

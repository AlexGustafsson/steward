package main

import (
	"fmt"
	"strings"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

// Complain on duplicates.
// TODO: Figure out what's sensible to do here.
func bailOnDuplicates(entries []indexing.Entry) error {
	for _, entry := range entries {
		identical := make([]string, 0)
		for _, other := range entries {
			if entry.AudioDigest == other.AudioDigest {
				identical = append(identical, entry.Name)
			}
		}
		if len(identical) > 1 {
			return fmt.Errorf("duplicate songs (identical audio digest): %s", strings.Join(identical, ","))
		}
	}

	return nil
}

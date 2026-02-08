package main

import (
	"encoding/json"
	"log/slog"
	"os"

	"github.com/AlexGustafsson/steward/internal/indexing"
)

func index(root string) {
	encoder := json.NewEncoder(os.Stdout)

	err := indexing.IndexDir(root, func(e indexing.Entry) error {
		return encoder.Encode(&e)
	})
	if err != nil {
		slog.Error("Failed to index directory", slog.Any("error", err))
		os.Exit(1)
	}
}

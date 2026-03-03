package main

import (
	"bufio"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/AlexGustafsson/steward/internal/indexing"
	"github.com/urfave/cli/v3"
)

func DiffAction(ctx context.Context, cmd *cli.Command) error {
	localIndex := cmd.StringArg("local")
	if localIndex == "" {
		_ = cli.ShowAppHelp(cmd)
		return ErrExit
	}

	remoteIndex := cmd.StringArg("remote")
	if remoteIndex == "" {
		_ = cli.ShowAppHelp(cmd)
		return ErrExit
	}

	localEntries, err := readEntriesFile(localIndex)
	if err != nil {
		return err
	}

	remoteEntries, err := readEntriesFile(remoteIndex)
	if err != nil {
		return err
	}

	if err := bailOnDuplicates(localEntries); err != nil {
		return err
	}
	if err := bailOnDuplicates(remoteEntries); err != nil {
		return err
	}

	onlyLocal := make([]indexing.Entry, 0)
	onlyRemote := make([]indexing.Entry, 0)
	inBoth := make([]indexing.Entry, 0)

	// TODO: Optimize if necessary
	for _, localEntry := range localEntries {
		i, ok := slices.BinarySearchFunc(remoteEntries, localEntry.AudioDigest, func(remoteEntry indexing.Entry, digest string) int {
			return strings.Compare(remoteEntry.AudioDigest, digest)
		})
		if ok {
			inBoth = append(inBoth, localEntry, remoteEntries[i])
		} else {
			onlyLocal = append(onlyLocal, localEntry)
		}
	}

	for _, remoteEntry := range remoteEntries {
		_, ok := slices.BinarySearchFunc(localEntries, remoteEntry.AudioDigest, func(localEntry indexing.Entry, digest string) int {
			return strings.Compare(localEntry.AudioDigest, digest)
		})
		if !ok {
			onlyRemote = append(onlyRemote, remoteEntry)
		}
	}

	encoder := json.NewEncoder(os.Stdout)
	switch cmd.String("output") {
	case "local-only":
		for _, entry := range onlyLocal {
			encoder.Encode(entry)
			fmt.Println()
		}
	case "remote-only":
		for _, entry := range onlyRemote {
			encoder.Encode(entry)
			fmt.Println()
		}
	case "diff":
		panic("not implemented")
	case "identical":
		panic("not implemented")
	default:
		return fmt.Errorf("invalid output type")
	}

	return nil
}

func readEntriesFile(path string) ([]indexing.Entry, error) {
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

	return readEntries(reader)
}

func readEntries(r io.Reader) ([]indexing.Entry, error) {
	entries := make([]indexing.Entry, 0)

	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		var entry indexing.Entry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			return nil, err
		}

		entries = append(entries, entry)
	}

	slices.SortFunc(entries, func(a indexing.Entry, b indexing.Entry) int {
		return strings.Compare(a.AudioDigest, b.AudioDigest)
	})

	return entries, nil
}

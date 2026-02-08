package main

import (
	"fmt"
	"log/slog"
	"os"
)

func main() {
	slog.SetLogLoggerLevel(slog.LevelDebug)

	command := os.Args[1]

	switch command {
	case "index":
		root := os.Args[2]
		index(root)
	case "diff":
		a := os.Args[2]
		b := os.Args[3]
		diff(a, b)
	case "upload":
		remote := os.Args[2]
		indexPath := ""
		if len(os.Args) > 3 {
			indexPath = os.Args[3]
		}
		upload(remote, indexPath)
	case "download":
		remote := os.Args[2]
		a := os.Args[3]
		b := os.Args[4]
		download(remote, a, b)
	default:
		panic(fmt.Sprintf("usage: %s index|diff", os.Args[0]))
	}
}

package main

import (
	"fmt"
	"os"
)

func main() {
	command := os.Args[1]

	switch command {
	case "index":
		root := os.Args[2]
		index(root)
	case "diff":
		a := os.Args[2]
		b := os.Args[3]
		diff(a, b)
	case "backup":
		switch os.Args[2] {
		case "upload":
			remote := os.Args[3]
			indexPath := ""
			if len(os.Args) > 4 {
				indexPath = os.Args[4]
			}
			upload(remote, indexPath)
		case "download":
			remote := os.Args[3]
			a := os.Args[4]
			b := os.Args[5]
			download(remote, a, b)
		}
	default:
		panic(fmt.Sprintf("usage: %s index|diff", os.Args[0]))
	}
}

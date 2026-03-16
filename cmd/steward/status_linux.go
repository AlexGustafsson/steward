package main

import (
	"os"
)

func StatusSignals() chan os.Signal {
	signals := make(chan os.Signal, 1)
	// TODO: Find alternative?
	// signal.Notify(signals, syscall.SIGINFO)
	return signals
}

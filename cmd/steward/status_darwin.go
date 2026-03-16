package main

import (
	"os"
	"os/signal"
	"syscall"
)

func StatusSignals() chan os.Signal {
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINFO)
	return signals
}

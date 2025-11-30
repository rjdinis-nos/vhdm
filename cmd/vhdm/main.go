// Package main is the entry point for vhdm CLI.
package main

import (
	"fmt"
	"os"

	"github.com/rjdinis/vhdm/internal/cli"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	rootCmd := cli.NewRootCommand(version, commit, date)
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

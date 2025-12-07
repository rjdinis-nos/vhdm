// Package main is the entry point for vhdm CLI.
package main

import (
	"fmt"
	"os"

	"github.com/rjdinis/vhdm/internal/cli"
	"github.com/rjdinis/vhdm/internal/types"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	rootCmd := cli.NewRootCommand(version, commit, date)
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)

		// If it's a VHDError with help text, print that too
		if vhdErr, ok := err.(*types.VHDError); ok && vhdErr.Help != "" {
			fmt.Fprintf(os.Stderr, "\n%s\n", vhdErr.Help)
		}

		os.Exit(1)
	}
}

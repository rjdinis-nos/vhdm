// Package cli implements the command-line interface for vhdm.
package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/config"
	"github.com/rjdinis/vhdm/internal/logging"
	"github.com/rjdinis/vhdm/internal/tracking"
	"github.com/rjdinis/vhdm/internal/wsl"
)

type AppContext struct {
	Config  *config.Config
	Logger  *logging.Logger
	Tracker *tracking.Tracker
	WSL     *wsl.Client
}

var (
	appCtx *AppContext
	quiet  bool
	debug  bool
	yes    bool
)

func NewRootCommand(version, commit, date string) *cobra.Command {
	rootCmd := &cobra.Command{
		Use:   "vhdm",
		Short: "WSL VHD Disk Management Tool",
		Long: `vhdm is a comprehensive CLI for managing VHD/VHDX files in WSL2.

Operations include attach, mount, format, unmount, detach, create, delete, 
resize, and status.`,
		Version: fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, date),
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			if cmd.Name() == "help" || cmd.Name() == "version" || cmd.Name() == "completion" {
				return nil
			}
			var err error
			appCtx, err = initContext()
			return err
		},
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	rootCmd.PersistentFlags().BoolVarP(&quiet, "quiet", "q", false, "Run in quiet mode")
	rootCmd.PersistentFlags().BoolVarP(&debug, "debug", "d", false, "Run in debug mode")
	rootCmd.PersistentFlags().BoolVarP(&yes, "yes", "y", false, "Auto-confirm prompts")

	rootCmd.AddCommand(
		newVersionCmd(version, commit, date),
		newCompletionCmd(),
		newStatusCmd(),
		newAttachCmd(),
		newDetachCmd(),
		newMountCmd(),
		newUmountCmd(),
		newFormatCmd(),
		newCreateCmd(),
		newDeleteCmd(),
		newResizeCmd(),
		newServiceCmd(),
	)

	return rootCmd
}

func initContext() (*AppContext, error) {
	cfg, err := config.Load()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}
	cfg.SetQuiet(quiet)
	cfg.SetDebug(debug)
	cfg.SetYes(yes)

	logger := logging.New(cfg.Quiet, cfg.Debug)

	tracker, err := tracking.New(cfg.TrackingFile)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize tracking: %w", err)
	}

	wslClient := wsl.NewClient(logger, cfg.SleepAfterAttach, cfg.DetachTimeout)

	return &AppContext{
		Config:  cfg,
		Logger:  logger,
		Tracker: tracker,
		WSL:     wslClient,
	}, nil
}

func getContext() *AppContext { return appCtx }

func newVersionCmd(version, commit, date string) *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("vhdm version %s\ncommit: %s\nbuilt: %s\n", version, commit, date)
		},
	}
}

package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newSyncCmd() *cobra.Command {
	var dryRun bool
	cmd := &cobra.Command{
		Use:   "sync",
		Short: "Synchronize tracking file with system state",
		Long: `Synchronize the tracking file with the current system state.

Removes stale mappings for VHDs that are no longer attached.`,
		Example: `  vhdm sync
  vhdm sync --dry-run`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSync(dryRun)
		},
	}
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Show what would be done without making changes")
	return cmd
}

func runSync(dryRun bool) error {
	ctx := getContext()
	log := ctx.Logger

	log.Debug("Sync operation starting")

	// Get all tracked paths
	paths, err := ctx.Tracker.GetAllPaths()
	if err != nil {
		return fmt.Errorf("failed to get tracked paths: %w", err)
	}

	var staleCount int
	var stalePaths []string

	for _, path := range paths {
		entry, err := ctx.Tracker.GetEntry(path)
		if err != nil {
			continue
		}

		// Check if VHD file exists
		wslPath := ctx.WSL.ConvertPath(path)
		fileExists := ctx.WSL.FileExists(wslPath)

		// Check if attached
		attached := false
		if entry.UUID != "" {
			attached, _ = ctx.WSL.IsAttached(entry.UUID)
		}

		if !fileExists || !attached {
			staleCount++
			stalePaths = append(stalePaths, path)
			
			reason := "file not found"
			if fileExists {
				reason = "not attached"
			}
			
			if dryRun {
				log.Info("[DRY-RUN] Would remove stale mapping: %s (%s)", path, reason)
			} else {
				log.Info("Removing stale mapping: %s (%s)", path, reason)
				if entry.UUID != "" {
					ctx.Tracker.SaveDetachHistory(path, entry.UUID, entry.DeviceName)
				}
				ctx.Tracker.RemoveMapping(path)
			}
		}
	}

	// Output
	if ctx.Config.Quiet {
		if dryRun {
			fmt.Printf("dry-run: would remove %d stale mappings\n", staleCount)
		} else {
			fmt.Printf("sync: removed %d stale mappings\n", staleCount)
		}
		return nil
	}

	if staleCount == 0 {
		log.Success("Tracking file is in sync (no stale mappings found)")
	} else if dryRun {
		log.Info("Dry-run: would remove %d stale mappings", staleCount)
	} else {
		log.Success("Sync complete: removed %d stale mappings", staleCount)
	}

	return nil
}

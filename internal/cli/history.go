package cli

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newHistoryCmd() *cobra.Command {
	var (
		limit   int
		vhdPath string
	)
	cmd := &cobra.Command{
		Use:   "history",
		Short: "Show VHD tracking history",
		Long: `Show VHD tracking history including current mappings and detach history.`,
		Example: `  vhdm history
  vhdm history --limit 20
  vhdm history --vhd-path C:/VMs/disk.vhdx`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runHistory(limit, vhdPath)
		},
	}
	cmd.Flags().IntVar(&limit, "limit", 10, "Number of detach history entries to show")
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "Show history for specific VHD")
	return cmd
}

func runHistory(limit int, vhdPath string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate
	if vhdPath != "" {
		if err := validation.ValidateWindowsPath(vhdPath); err != nil {
			return err
		}
	}

	log.Debug("History operation starting")

	// Get current mappings
	paths, err := ctx.Tracker.GetAllPaths()
	if err != nil {
		return fmt.Errorf("failed to get mappings: %w", err)
	}

	// Get detach history
	history, err := ctx.Tracker.GetDetachHistory(limit)
	if err != nil {
		return fmt.Errorf("failed to get history: %w", err)
	}

	if ctx.Config.Quiet {
		// Quiet mode: simple output
		fmt.Printf("mappings: %d\n", len(paths))
		fmt.Printf("detach_history: %d\n", len(history))
		return nil
	}

	// Print current mappings
	fmt.Println()
	fmt.Println("Current Mappings (Attached VHDs)")
	fmt.Println()
	
	if len(paths) == 0 {
		fmt.Println("  No VHDs currently tracked")
	} else {
		colWidths := []int{40, 36, 8, 20}
		headers := []string{"Path", "UUID", "Device", "Mount Points"}
		utils.PrintTableHeader(colWidths, headers)
		
		for _, path := range paths {
			entry, _ := ctx.Tracker.GetEntry(path)
			uuid := entry.UUID
			if uuid == "" {
				uuid = "(none)"
			}
			dev := entry.DeviceName
			if dev == "" {
				dev = "-"
			}
			mp := strings.Join(entry.MountPoints, ",")
			if mp == "" {
				mp = "-"
			}
			utils.PrintTableRow(colWidths, path, uuid, dev, mp)
		}
		utils.PrintTableFooter(colWidths)
	}

	// Print detach history
	fmt.Println()
	fmt.Println("Detach History")
	fmt.Println()
	
	if len(history) == 0 {
		fmt.Println("  No detach history")
	} else {
		colWidths := []int{40, 36, 8, 20}
		headers := []string{"Path", "UUID", "Device", "Timestamp"}
		utils.PrintTableHeader(colWidths, headers)
		
		for _, entry := range history {
			uuid := entry.UUID
			dev := entry.DeviceName
			if dev == "" {
				dev = "-"
			}
			// Format timestamp
			ts := entry.Timestamp
			if len(ts) > 19 {
				ts = ts[:19]
			}
			utils.PrintTableRow(colWidths, entry.Path, uuid, dev, ts)
		}
		utils.PrintTableFooter(colWidths)
	}

	return nil
}

package cli

import (
	"fmt"
	"github.com/spf13/cobra"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newHistoryCmd() *cobra.Command {
	var (
		limit   int
		vhdPath string
	)
	cmd := &cobra.Command{
		Use:     "history",
		Short:   "Show tracking history",
		Example: "  vhdm history\n  vhdm history --limit 20",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runHistory(limit, vhdPath)
		},
	}
	cmd.Flags().IntVar(&limit, "limit", 10, "Number of events")
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "Specific VHD path")
	return cmd
}

func runHistory(limit int, vhdPath string) error {
	ctx := getContext()
	ctx.Logger.Debug("History operation starting")
	history, err := ctx.Tracker.GetDetachHistory(limit)
	if err != nil {
		return fmt.Errorf("failed to get history: %w", err)
	}
	if len(history) == 0 {
		fmt.Println("No detach history recorded.")
		return nil
	}
	if ctx.Config.Quiet {
		for _, e := range history {
			fmt.Printf("%s (%s): detached at %s\n", e.Path, e.UUID, e.Timestamp)
		}
		return nil
	}
	rows := make([][]string, 0, len(history))
	for _, e := range history {
		dev := "-"
		if e.DevName != "" {
			dev = e.DevName
		}
		rows = append(rows, []string{e.Path, e.UUID, dev, e.Timestamp})
	}
	utils.PrintTable(fmt.Sprintf("Detach History (last %d)", len(history)),
		[]string{"Path", "UUID", "Device", "Timestamp"}, rows, 40, 36, 8, 25)
	return nil
}

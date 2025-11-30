package cli

import (
	"fmt"
	"github.com/spf13/cobra"
	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
)

func newAttachCmd() *cobra.Command {
	var vhdPath string
	cmd := &cobra.Command{
		Use:     "attach",
		Short:   "Attach a VHD to WSL (without mounting)",
		Example: "  vhdm attach --vhd-path C:/VMs/disk.vhdx",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAttach(vhdPath)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.MarkFlagRequired("vhd-path")
	return cmd
}

func runAttach(vhdPath string) error {
	ctx := getContext()
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{Op: "attach", Path: vhdPath, Err: err}
	}
	ctx.Logger.Debug("Attach operation starting for: %s", vhdPath)
	// TODO: Implement WSL attach operations
	fmt.Printf("TODO: Attach VHD: %s\n", vhdPath)
	ctx.Logger.Warn("Attach command not yet fully implemented")
	return nil
}

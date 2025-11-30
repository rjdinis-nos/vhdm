package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
)

func newResizeCmd() *cobra.Command {
	var (
		vhdPath string
		newSize string
	)
	cmd := &cobra.Command{
		Use:   "resize",
		Short: "Resize a VHD file",
		Long: `Resize a VHD file to a new size.

This is a complex operation that creates a new VHD, migrates data,
and preserves the original as a backup.

NOTE: This command is not yet fully implemented in Go.
Please use the bash script for resize operations.`,
		Example: `  vhdm resize --vhd-path C:/VMs/disk.vhdx --size 10G`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runResize(vhdPath, newSize)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.Flags().StringVar(&newSize, "size", "", "New VHD size (e.g., 10G)")
	cmd.MarkFlagRequired("vhd-path")
	cmd.MarkFlagRequired("size")
	return cmd
}

func runResize(vhdPath, newSize string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{Op: "resize", Path: vhdPath, Err: err}
	}
	if err := validation.ValidateSizeString(newSize); err != nil {
		return &types.VHDError{Op: "resize", Err: err}
	}

	log.Debug("Resize operation starting")

	// Check if file exists
	wslPath := ctx.WSL.ConvertPath(vhdPath)
	if !ctx.WSL.FileExists(wslPath) {
		return fmt.Errorf("VHD file not found: %s", vhdPath)
	}

	// TODO: Implement full resize logic
	// This is a complex operation involving:
	// 1. Create new VHD with new size
	// 2. Attach both VHDs
	// 3. Format new VHD
	// 4. Mount both VHDs
	// 5. rsync data from old to new
	// 6. Verify file counts
	// 7. Unmount and detach both
	// 8. Rename old to backup
	// 9. Rename new to original name
	// 10. Update tracking

	log.Warn("Resize command is not yet fully implemented in Go")
	log.Info("Please use the bash script for resize operations:")
	log.Info("  ./vhdm.sh resize --vhd-path %s --size %s", vhdPath, newSize)

	return fmt.Errorf("resize not implemented - use bash script")
}

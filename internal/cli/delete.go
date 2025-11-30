package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newDeleteCmd() *cobra.Command {
	var vhdPath string
	cmd := &cobra.Command{
		Use:   "delete",
		Short: "Delete a VHD file",
		Long: `Delete a VHD file from disk.

The VHD must be detached before deletion.`,
		Example: "  vhdm delete --vhd-path C:/VMs/disk.vhdx",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDelete(vhdPath)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.MarkFlagRequired("vhd-path")
	return cmd
}

func runDelete(vhdPath string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{Op: "delete", Path: vhdPath, Err: err}
	}

	log.Debug("Delete operation starting")

	// Check if file exists
	wslPath := ctx.WSL.ConvertPath(vhdPath)
	if !ctx.WSL.FileExists(wslPath) {
		return fmt.Errorf("VHD file not found: %s", vhdPath)
	}

	// Check if attached
	uuid, _ := ctx.Tracker.LookupUUIDByPath(vhdPath)
	if uuid != "" {
		attached, _ := ctx.WSL.IsAttached(uuid)
		if attached {
			return fmt.Errorf("VHD is still attached. Run 'vhdm detach --vhd-path %s' first", vhdPath)
		}
	}

	// Confirm deletion
	if !ctx.Config.Yes {
		log.Warn("This will permanently delete: %s", vhdPath)
		log.Warn("Run with --yes to confirm")
		return fmt.Errorf("operation cancelled")
	}

	// Delete file
	log.Info("Deleting VHD file...")
	if err := ctx.WSL.DeleteVHD(wslPath); err != nil {
		return fmt.Errorf("failed to delete: %w", err)
	}

	// Remove from tracking
	ctx.Tracker.RemoveMapping(vhdPath)

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("%s: deleted\n", vhdPath)
		return nil
	}

	log.Success("VHD deleted successfully")
	
	pairs := [][2]string{
		{"Path", vhdPath},
		{"Status", "deleted"},
	}
	utils.KeyValueTable("Delete Result", pairs, 14, 50)
	
	return nil
}

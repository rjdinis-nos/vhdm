package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newFormatCmd() *cobra.Command {
	var (
		devName string
		fsType  string
	)
	cmd := &cobra.Command{
		Use:   "format",
		Short: "Format a VHD with a filesystem",
		Long: `Format an attached VHD with a filesystem.

WARNING: This will erase all data on the device!`,
		Example: `  vhdm format --dev-name sde --type ext4
  vhdm format --dev-name sde --type xfs`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runFormat(devName, fsType)
		},
	}
	cmd.Flags().StringVar(&devName, "dev-name", "", "Device name (e.g., sde)")
	cmd.Flags().StringVar(&fsType, "type", "ext4", "Filesystem type")
	cmd.MarkFlagRequired("dev-name")
	return cmd
}

func runFormat(devName, fsType string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate
	if err := validation.ValidateDeviceName(devName); err != nil {
		return &types.VHDError{Op: "format", Err: err}
	}
	if err := validation.ValidateFilesystemType(fsType); err != nil {
		return &types.VHDError{Op: "format", Err: err}
	}

	log.Debug("Format operation starting")

	// Check device exists
	if !ctx.WSL.DeviceExists(devName) {
		return fmt.Errorf("device /dev/%s not found", devName)
	}

	// Check if already formatted
	isFormatted, _ := ctx.WSL.IsFormatted(devName)
	if isFormatted && !ctx.Config.Yes {
		log.Warn("Device is already formatted. This will erase all data!")
		log.Warn("Run with --yes to confirm, or use 'vhdm format --dev-name %s --type %s -y'", devName, fsType)
		return fmt.Errorf("operation cancelled")
	}

	// Format
	log.Info("Formatting /dev/%s with %s...", devName, fsType)
	uuid, err := ctx.WSL.Format(devName, fsType)
	if err != nil {
		return fmt.Errorf("format failed: %w", err)
	}

	// Update tracking if we can find the path
	path, _ := ctx.Tracker.LookupPathByDevName(devName)
	if path != "" {
		ctx.Tracker.SaveMapping(path, uuid, "", devName)
	}

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("/dev/%s: formatted (%s)\n", devName, uuid)
		return nil
	}

	log.Success("Device formatted successfully")
	
	pairs := [][2]string{
		{"Device", "/dev/" + devName},
		{"Filesystem", fsType},
		{"UUID", uuid},
		{"Status", "formatted"},
	}
	if path != "" {
		pairs = append([][2]string{{"Path", path}}, pairs...)
	}
	
	utils.KeyValueTable("Format Result", pairs, 14, 50)
	
	fmt.Println()
	log.Info("To mount this VHD, run:")
	log.Info("  vhdm mount --uuid %s --mount-point /mnt/your-mount-point", uuid)
	
	return nil
}

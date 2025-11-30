package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newCreateCmd() *cobra.Command {
	var (
		vhdPath string
		size    string
		fsType  string
		force   bool
	)
	cmd := &cobra.Command{
		Use:   "create",
		Short: "Create a new VHD file",
		Long: `Create a new VHD file.

Without --format, only creates the VHD file.
With --format, creates, attaches, and formats the VHD.`,
		Example: `  vhdm create --vhd-path C:/VMs/disk.vhdx --size 5G
  vhdm create --vhd-path C:/VMs/disk.vhdx --size 5G --format ext4`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runCreate(vhdPath, size, fsType, force)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.Flags().StringVar(&size, "size", "", "VHD size (e.g., 5G, 500M)")
	cmd.Flags().StringVar(&fsType, "format", "", "Filesystem type (creates and formats)")
	cmd.Flags().BoolVar(&force, "force", false, "Overwrite existing file")
	cmd.MarkFlagRequired("vhd-path")
	cmd.MarkFlagRequired("size")
	return cmd
}

func runCreate(vhdPath, size, fsType string, force bool) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{Op: "create", Path: vhdPath, Err: err}
	}
	if err := validation.ValidateSizeString(size); err != nil {
		return &types.VHDError{Op: "create", Err: err}
	}
	if fsType != "" {
		if err := validation.ValidateFilesystemType(fsType); err != nil {
			return &types.VHDError{Op: "create", Err: err}
		}
	}

	log.Debug("Create operation starting")

	// Check if file exists
	wslPath := ctx.WSL.ConvertPath(vhdPath)
	if ctx.WSL.FileExists(wslPath) && !force {
		return fmt.Errorf("VHD file already exists: %s (use --force to overwrite)", vhdPath)
	}

	// Create VHD
	log.Info("Creating VHD: %s (%s)...", vhdPath, size)
	if err := ctx.WSL.CreateVHD(wslPath, size); err != nil {
		return fmt.Errorf("failed to create VHD: %w", err)
	}
	log.Success("VHD file created")

	// If no format requested, we're done
	if fsType == "" {
		if ctx.Config.Quiet {
			fmt.Printf("%s: created\n", vhdPath)
			return nil
		}
		
		pairs := [][2]string{
			{"Path", vhdPath},
			{"Size", size},
			{"Status", "created (unformatted)"},
		}
		utils.KeyValueTable("Create Result", pairs, 14, 50)
		
		fmt.Println()
		log.Info("To attach and format this VHD, run:")
		log.Info("  vhdm attach --vhd-path %s", vhdPath)
		log.Info("  vhdm format --dev-name <device> --type ext4")
		return nil
	}

	// Attach VHD
	log.Info("Attaching VHD...")
	oldDevices, err := ctx.WSL.GetBlockDevices()
	if err != nil {
		return fmt.Errorf("failed to get block devices: %w", err)
	}
	
	if _, err := ctx.WSL.AttachVHD(vhdPath); err != nil {
		return fmt.Errorf("failed to attach: %w", err)
	}

	// Detect new device
	devName, err := ctx.WSL.DetectNewDevice(oldDevices)
	if err != nil {
		return fmt.Errorf("failed to detect device: %w", err)
	}
	log.Success("VHD attached as /dev/%s", devName)

	// Format
	log.Info("Formatting with %s...", fsType)
	uuid, err := ctx.WSL.Format(devName, fsType)
	if err != nil {
		return fmt.Errorf("failed to format: %w", err)
	}
	log.Success("Formatted with UUID: %s", uuid)

	// Save tracking
	ctx.Tracker.SaveMapping(vhdPath, uuid, "", devName)

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("%s (%s): created,formatted\n", vhdPath, uuid)
		return nil
	}

	pairs := [][2]string{
		{"Path", vhdPath},
		{"Size", size},
		{"UUID", uuid},
		{"Device", "/dev/" + devName},
		{"Filesystem", fsType},
		{"Status", "created and formatted"},
	}
	utils.KeyValueTable("Create Result", pairs, 14, 50)
	
	fmt.Println()
	log.Info("To mount this VHD, run:")
	log.Info("  vhdm mount --vhd-path %s --mount-point /mnt/your-mount-point", vhdPath)
	
	return nil
}

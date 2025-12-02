package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newAttachCmd() *cobra.Command {
	var vhdPath string
	cmd := &cobra.Command{
		Use:   "attach",
		Short: "Attach a VHD to WSL (without mounting)",
		Long: `Attach a VHD file to WSL as a block device.

The VHD will be accessible as /dev/sdX after attachment.
Use 'mount' command to attach AND mount in one step.`,
		Example: "  vhdm attach --vhd-path C:/VMs/disk.vhdx",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAttach(vhdPath)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.MarkFlagRequired("vhd-path")
	return cmd
}

func runAttach(vhdPath string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate path
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{
			Op:   "attach",
			Path: vhdPath,
			Err:  err,
			Help: "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)",
		}
	}

	log.Debug("Attach operation starting for: %s", vhdPath)

	// Check if VHD file exists
	wslPath := ctx.WSL.ConvertPath(vhdPath)
	if !ctx.WSL.FileExists(wslPath) {
		return &types.VHDError{
			Op:   "attach",
			Path: vhdPath,
			Err:  types.ErrVHDNotFound,
			Help: fmt.Sprintf("VHD file not found at: %s", wslPath),
		}
	}

	// Take snapshot of current devices before attach
	oldDevices, err := ctx.WSL.GetBlockDevices()
	if err != nil {
		return fmt.Errorf("failed to get block devices: %w", err)
	}

	// Attempt to attach
	_, err = ctx.WSL.AttachVHD(vhdPath)
	if err != nil {
		if types.IsAlreadyAttached(err) {
			// VHD is already attached - find its UUID
			log.Debug("VHD is already attached, looking up UUID...")
			
			// Try tracking file first
			uuid, _ := ctx.Tracker.LookupUUIDByPath(vhdPath)
			if uuid == "" {
				// Fall back to device discovery
				uuid, _ = ctx.WSL.FindUUIDByPath(vhdPath)
			}
			
			devName := ""
			if uuid != "" {
				devName, _ = ctx.WSL.GetDeviceByUUID(uuid)
			}
			
			if ctx.Config.Quiet {
				if uuid != "" {
					fmt.Printf("%s (%s): already attached\n", vhdPath, uuid)
				} else {
					fmt.Printf("%s: already attached\n", vhdPath)
				}
				return nil
			}

			log.Info("VHD is already attached")
			printAttachResult(vhdPath, uuid, devName, false, uuid == "")
			return nil
		}
		return &types.VHDError{
			Op:   "attach",
			Path: vhdPath,
			Err:  err,
		}
	}

	// Detect new device
	devName, err := ctx.WSL.DetectNewDevice(oldDevices)
	if err != nil {
		return fmt.Errorf("failed to detect attached device: %w", err)
	}

	// Get UUID if formatted
	uuid, _ := ctx.WSL.GetUUIDByDevice(devName)

	// Save to tracking file
	if err := ctx.Tracker.SaveMapping(vhdPath, uuid, "", devName); err != nil {
		log.Warn("Failed to save tracking info: %v", err)
	}

	// Output
	if ctx.Config.Quiet {
		if uuid != "" {
			fmt.Printf("%s (%s): attached\n", vhdPath, uuid)
		} else {
			fmt.Printf("%s (/dev/%s): attached,unformatted\n", vhdPath, devName)
		}
		return nil
	}

	log.Success("VHD attached successfully")
	printAttachResult(vhdPath, uuid, devName, true, uuid == "")
	return nil
}

func printAttachResult(path, uuid, devName string, newlyAttached, unformatted bool) {
	fmt.Println()
	fmt.Println("VHD Attach Result")
	fmt.Println()
	
	pairs := [][2]string{
		{"Path", path},
	}
	
	if uuid != "" {
		pairs = append(pairs, [2]string{"UUID", uuid})
	} else if unformatted {
		pairs = append(pairs, [2]string{"UUID", "(unformatted)"})
	}
	
	if devName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + devName})
	}
	
	status := "attached"
	if newlyAttached {
		status = "attached (newly)"
	}
	if unformatted {
		status += " - needs formatting"
	}
	pairs = append(pairs, [2]string{"Status", status})
	
	utils.KeyValueTable("", pairs, 14, 50)
	
	if unformatted {
		fmt.Println()
		fmt.Printf("To format this VHD, run:\n")
		fmt.Printf("  vhdm format --dev-name %s --type ext4\n", devName)
	}
}

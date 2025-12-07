package cli

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newMountCmd() *cobra.Command {
	var (
		vhdPath    string
		uuid       string
		devName    string
		mountPoint string
	)
	cmd := &cobra.Command{
		Use:   "mount",
		Short: "Attach and mount a VHD",
		Long: `Attach and mount a VHD file to WSL.

This is an orchestration command that:
1. Attaches the VHD if not already attached
2. Mounts the VHD to the specified mount point

The VHD must be formatted before mounting.`,
		Example: `  vhdm mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
  vhdm mount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --mount-point /mnt/data
  vhdm mount --dev-name sde --mount-point /mnt/data`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runMount(vhdPath, uuid, devName, mountPoint)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&devName, "dev-name", "", "Device name (e.g., sde)")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path")
	cmd.MarkFlagRequired("mount-point")
	return cmd
}

func runMount(vhdPath, uuid, devName, mountPoint string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate inputs
	if vhdPath == "" && uuid == "" && devName == "" {
		return fmt.Errorf("at least one of --vhd-path, --uuid, or --dev-name is required")
	}

	if vhdPath != "" {
		if err := validation.ValidateWindowsPath(vhdPath); err != nil {
			return &types.VHDError{Op: "mount", Path: vhdPath, Err: err}
		}
	}
	if uuid != "" {
		if err := validation.ValidateUUID(uuid); err != nil {
			return &types.VHDError{Op: "mount", Err: err}
		}
	}
	if devName != "" {
		if err := validation.ValidateDeviceName(devName); err != nil {
			return &types.VHDError{Op: "mount", Err: err}
		}
		// Normalize device name (strip /dev/ prefix if present)
		devName = strings.TrimPrefix(devName, "/dev/")
	}
	if err := validation.ValidateMountPoint(mountPoint); err != nil {
		return &types.VHDError{Op: "mount", Err: err}
	}

	log.Debug("Mount operation starting")

	var wasAttached bool

	// Step 1: Attach if needed
	if vhdPath != "" {
		// Check if already attached - first check tracking, then verify in system
		existingUUID, _ := ctx.Tracker.LookupUUIDByPath(vhdPath)
		if existingUUID != "" {
			// Verify the UUID is actually attached in the system
			attached, _ := ctx.WSL.IsAttached(existingUUID)
			if attached {
				uuid = existingUUID
				wasAttached = true
				log.Debug("VHD already attached with UUID: %s", uuid)
			} else {
				log.Debug("UUID %s found in tracking but not attached, will attach", existingUUID)
				// Fall through to attach
				existingUUID = ""
			}
		}

		if existingUUID == "" {
			// Try to attach
			oldDevices, err := ctx.WSL.GetBlockDevices()
			if err != nil {
				return fmt.Errorf("failed to get block devices: %w", err)
			}

			_, err = ctx.WSL.AttachVHD(vhdPath)
			if err != nil {
				if types.IsAlreadyAttached(err) {
					wasAttached = true
					// Try to find UUID from disk
					uuid, _ = ctx.WSL.FindUUIDByPath(vhdPath)
				} else {
					return fmt.Errorf("failed to attach: %w", err)
				}
			} else {
				// Detect new device
				devName, err = ctx.WSL.DetectNewDevice(oldDevices)
				if err != nil {
					return fmt.Errorf("failed to detect device: %w", err)
				}
				uuid, _ = ctx.WSL.GetUUIDByDevice(devName)
				log.Debug("Attached new device: %s (UUID: %s)", devName, uuid)
			}
		}
	}

	// If devName provided but no UUID yet, get UUID from device
	if devName != "" && uuid == "" {
		uuid, _ = ctx.WSL.GetUUIDByDevice(devName)
		wasAttached = true // device already exists, so it's attached
		log.Debug("Using device %s (UUID: %s)", devName, uuid)
	}

	// Check if VHD has UUID (formatted)
	if uuid == "" {
		if devName == "" && vhdPath != "" {
			// Try to find device
			devName, _ = ctx.Tracker.LookupDevNameByPath(vhdPath)
		}
		return &types.VHDError{
			Op:   "mount",
			Path: vhdPath,
			Err:  types.ErrVHDNotFormatted,
			Help: fmt.Sprintf("VHD is not formatted. Run: vhdm format --dev-name %s --type ext4", devName),
		}
	}

	// Get device name
	if devName == "" {
		devName, _ = ctx.WSL.GetDeviceByUUID(uuid)
	}

	// Check if already mounted
	existingMP, _ := ctx.WSL.GetMountPoint(uuid)
	if existingMP != "" {
		if existingMP == mountPoint {
			// Already mounted at same location
			// Update tracking to ensure OriginalPath is set (for migration from old format)
			if vhdPath != "" {
				if err := ctx.Tracker.SaveMapping(vhdPath, uuid, mountPoint, devName); err != nil {
					log.Warn("Failed to save tracking: %v", err)
				}
			}
			if ctx.Config.Quiet {
				fmt.Printf("%s: already mounted at %s\n", vhdPath, mountPoint)
			} else {
				log.Info("VHD is already mounted at %s", mountPoint)
				printMountResult(vhdPath, uuid, devName, mountPoint, false)
			}
			return nil
		}
		// Mounted at different location
		return fmt.Errorf("VHD is already mounted at %s", existingMP)
	}

	// Step 2: Mount
	if err := ctx.WSL.MountByUUID(uuid, mountPoint); err != nil {
		return fmt.Errorf("failed to mount: %w", err)
	}

	// Update tracking
	if vhdPath != "" {
		if err := ctx.Tracker.SaveMapping(vhdPath, uuid, mountPoint, devName); err != nil {
			log.Warn("Failed to save tracking: %v", err)
		}
	}

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("%s (%s): mounted at %s\n", vhdPath, uuid, mountPoint)
		return nil
	}

	log.Success("VHD mounted successfully")
	printMountResult(vhdPath, uuid, devName, mountPoint, !wasAttached)
	return nil
}

func printMountResult(path, uuid, devName, mountPoint string, wasNewlyAttached bool) {
	pairs := [][2]string{}

	if path != "" {
		pairs = append(pairs, [2]string{"Path", path})
	}
	pairs = append(pairs, [2]string{"UUID", uuid})
	if devName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + devName})
	}
	pairs = append(pairs, [2]string{"Mount Point", mountPoint})

	status := "mounted"
	if wasNewlyAttached {
		status = "attached and mounted"
	}
	pairs = append(pairs, [2]string{"Status", status})

	utils.KeyValueTable("VHD Mount Result", pairs, 14, 50)
}

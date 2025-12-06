package cli

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newDetachCmd() *cobra.Command {
	var (
		vhdPath string
		uuid    string
		devName string
	)
	cmd := &cobra.Command{
		Use:   "detach",
		Short: "Detach a VHD from WSL",
		Long: `Detach a VHD disk from WSL.

If the VHD is mounted, it will be unmounted first.`,
		Example: `  vhdm detach --vhd-path C:/VMs/disk.vhdx
  vhdm detach --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293
  vhdm detach --dev-name sde`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDetach(vhdPath, uuid, devName)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&devName, "dev-name", "", "Device name (e.g., sde)")
	return cmd
}

func runDetach(vhdPath, uuid, devName string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate inputs
	if vhdPath == "" && uuid == "" && devName == "" {
		return fmt.Errorf("at least one of --vhd-path, --uuid, or --dev-name is required")
	}

	if vhdPath != "" {
		if err := validation.ValidateWindowsPath(vhdPath); err != nil {
			return &types.VHDError{Op: "detach", Path: vhdPath, Err: err}
		}
	}
	if uuid != "" {
		if err := validation.ValidateUUID(uuid); err != nil {
			return &types.VHDError{Op: "detach", Err: err}
		}
	}
	if devName != "" {
		if err := validation.ValidateDeviceName(devName); err != nil {
			return &types.VHDError{Op: "detach", Err: err}
		}
		// Normalize device name (strip /dev/ prefix if present)
		devName = strings.TrimPrefix(devName, "/dev/")
	}

	log.Debug("Detach operation starting")

	// Find VHD path if not provided
	if vhdPath == "" {
		// Try to find path from UUID
		if uuid != "" {
			path, _ := ctx.Tracker.LookupPathByUUID(uuid)
			if path != "" {
				vhdPath = path
			}
		}
		// Try to find from device name
		if vhdPath == "" && devName != "" {
			path, _ := ctx.Tracker.LookupPathByDevName(devName)
			if path != "" {
				vhdPath = path
			}
		}
	}

	// Find UUID if not provided
	if uuid == "" && devName != "" {
		uuid, _ = ctx.WSL.GetUUIDByDevice(devName)
	}
	if uuid == "" && vhdPath != "" {
		uuid, _ = ctx.Tracker.LookupUUIDByPath(vhdPath)
	}

	// Find device name if not provided
	if devName == "" && uuid != "" {
		devName, _ = ctx.WSL.GetDeviceByUUID(uuid)
	}

	// Check if mounted and unmount first
	if uuid != "" {
		mounted, _ := ctx.WSL.IsMounted(uuid)
		if mounted {
			log.Info("VHD is mounted, unmounting first...")
			mountPoint, _ := ctx.WSL.GetMountPoint(uuid)
			if mountPoint != "" {
				if err := ctx.WSL.Unmount(mountPoint); err != nil {
					return fmt.Errorf("failed to unmount: %w", err)
				}
				log.Success("Unmounted from %s", mountPoint)
			}
		}
	}

	// Need vhdPath for detach
	if vhdPath == "" {
		return fmt.Errorf("VHD path is required for detach. Use --vhd-path or ensure the VHD is tracked")
	}

	// Detach from WSL
	if err := ctx.WSL.DetachVHD(vhdPath); err != nil {
		if types.IsNotAttached(err) {
			// Already detached - update tracking to reflect current state
			if uuid != "" {
				ctx.Tracker.SaveMapping(vhdPath, uuid, "", "")
			}
			if ctx.Config.Quiet {
				fmt.Printf("%s: already detached\n", vhdPath)
			} else {
				log.Info("VHD is already detached")
			}
			return nil
		}
		return fmt.Errorf("failed to detach: %w", err)
	}

	// Update tracking - keep entry but clear device/mount info
	if uuid != "" {
		ctx.Tracker.SaveMapping(vhdPath, uuid, "", "")
	}

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("%s: detached\n", vhdPath)
		return nil
	}

	log.Success("VHD detached successfully")

	pairs := [][2]string{
		{"Path", vhdPath},
	}
	if uuid != "" {
		pairs = append(pairs, [2]string{"UUID", uuid})
	}
	if devName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + devName})
	}
	pairs = append(pairs, [2]string{"Status", "detached"})

	utils.KeyValueTable("VHD Detach Result", pairs, 14, 50)

	return nil
}

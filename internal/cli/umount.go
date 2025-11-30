package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newUmountCmd() *cobra.Command {
	var (
		vhdPath    string
		uuid       string
		mountPoint string
		doDetach   bool
		force      bool
	)
	cmd := &cobra.Command{
		Use:     "umount",
		Aliases: []string{"unmount"},
		Short:   "Unmount a VHD",
		Long: `Unmount a VHD from the filesystem.

By default, only unmounts. Use --vhd-path to also detach after unmounting.`,
		Example: `  vhdm umount --mount-point /mnt/data
  vhdm umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293
  vhdm umount --vhd-path C:/VMs/disk.vhdx  # unmount and detach`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runUmount(vhdPath, uuid, mountPoint, doDetach, force)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (unmount + detach)")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path")
	cmd.Flags().BoolVar(&doDetach, "detach", false, "Also detach after unmounting")
	cmd.Flags().BoolVar(&force, "force", false, "Force unmount (lazy)")
	return cmd
}

func runUmount(vhdPath, uuid, mountPoint string, doDetach, force bool) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate inputs
	if vhdPath == "" && uuid == "" && mountPoint == "" {
		return fmt.Errorf("at least one of --vhd-path, --uuid, or --mount-point is required")
	}

	if vhdPath != "" {
		if err := validation.ValidateWindowsPath(vhdPath); err != nil {
			return &types.VHDError{Op: "umount", Path: vhdPath, Err: err}
		}
		doDetach = true // vhd-path implies detach
	}
	if uuid != "" {
		if err := validation.ValidateUUID(uuid); err != nil {
			return &types.VHDError{Op: "umount", Err: err}
		}
	}
	if mountPoint != "" {
		if err := validation.ValidateMountPoint(mountPoint); err != nil {
			return &types.VHDError{Op: "umount", Err: err}
		}
	}

	log.Debug("Umount operation starting")

	var devName string

	// Find UUID if not provided
	if uuid == "" {
		if mountPoint != "" {
			uuid, _ = ctx.WSL.FindUUIDByMountPoint(mountPoint)
		}
		if uuid == "" && vhdPath != "" {
			uuid, _ = ctx.Tracker.LookupUUIDByPath(vhdPath)
		}
	}

	// Find mount point if not provided
	if mountPoint == "" && uuid != "" {
		mountPoint, _ = ctx.WSL.GetMountPoint(uuid)
	}

	// Find device name
	if uuid != "" {
		devName, _ = ctx.WSL.GetDeviceByUUID(uuid)
	}

	// Find vhd path if needed for detach
	if vhdPath == "" && doDetach && uuid != "" {
		vhdPath, _ = ctx.Tracker.LookupPathByUUID(uuid)
	}

	// Check if mounted
	if mountPoint == "" {
		if ctx.Config.Quiet {
			fmt.Printf("not mounted\n")
		} else {
			log.Info("VHD is not mounted")
		}
		
		// Even if not mounted, might want to detach
		if doDetach && vhdPath != "" {
			log.Info("Detaching VHD...")
			return runDetach(vhdPath, uuid, devName)
		}
		return nil
	}

	// Unmount
	var err error
	if force {
		err = ctx.WSL.ForceUnmount(mountPoint)
	} else {
		err = ctx.WSL.Unmount(mountPoint)
	}
	if err != nil {
		return fmt.Errorf("failed to unmount: %w", err)
	}

	// Update tracking - remove mount point
	if vhdPath != "" {
		ctx.Tracker.UpdateMountPoints(vhdPath, []string{})
	}

	// Detach if requested
	if doDetach && vhdPath != "" {
		// Save detach history
		if uuid != "" {
			ctx.Tracker.SaveDetachHistory(vhdPath, uuid, devName)
		}
		ctx.Tracker.RemoveMapping(vhdPath)

		if err := ctx.WSL.DetachVHD(vhdPath); err != nil {
			log.Warn("Failed to detach: %v", err)
		} else {
			log.Success("VHD unmounted and detached")
			printUmountResult(vhdPath, uuid, devName, mountPoint, true)
			return nil
		}
	}

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("%s: unmounted\n", mountPoint)
		return nil
	}

	log.Success("VHD unmounted successfully")
	printUmountResult(vhdPath, uuid, devName, mountPoint, false)
	return nil
}

func printUmountResult(path, uuid, devName, mountPoint string, wasDetached bool) {
	pairs := [][2]string{}
	
	if path != "" {
		pairs = append(pairs, [2]string{"Path", path})
	}
	if uuid != "" {
		pairs = append(pairs, [2]string{"UUID", uuid})
	}
	if devName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + devName})
	}
	pairs = append(pairs, [2]string{"Mount Point", mountPoint})
	
	status := "unmounted"
	if wasDetached {
		status = "unmounted and detached"
	}
	pairs = append(pairs, [2]string{"Status", status})
	
	utils.KeyValueTable("VHD Umount Result", pairs, 14, 50)
}

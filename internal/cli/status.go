package cli

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newStatusCmd() *cobra.Command {
	var (
		vhdPath    string
		uuid       string
		mountPoint string
		showAll    bool
	)
	cmd := &cobra.Command{
		Use:   "status",
		Short: "Show VHD disk status",
		Long: `Show current VHD disk status.

Without flags, shows all tracked VHDs.
Use specific flags to query particular VHDs.`,
		Example: `  vhdm status --all
  vhdm status --vhd-path C:/VMs/disk.vhdx
  vhdm status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runStatus(vhdPath, uuid, mountPoint, showAll)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path")
	cmd.Flags().BoolVar(&showAll, "all", false, "Show all tracked VHDs")
	return cmd
}

func runStatus(vhdPath, uuid, mountPoint string, showAll bool) error {
	ctx := getContext()
	log := ctx.Logger

	// Default to --all if no flags
	if vhdPath == "" && uuid == "" && mountPoint == "" {
		showAll = true
	}

	// Validate inputs
	if vhdPath != "" {
		if err := validation.ValidateWindowsPath(vhdPath); err != nil {
			return &types.VHDError{Op: "status", Path: vhdPath, Err: err}
		}
	}
	if uuid != "" {
		if err := validation.ValidateUUID(uuid); err != nil {
			return &types.VHDError{Op: "status", Err: err}
		}
	}

	log.Debug("Status operation starting")

	if showAll {
		return showAllStatus(ctx)
	}

	// Single VHD status
	return showSingleStatus(ctx, vhdPath, uuid, mountPoint)
}

func showAllStatus(ctx *AppContext) error {
	paths, err := ctx.Tracker.GetAllPaths()
	if err != nil {
		return fmt.Errorf("failed to get tracked VHDs: %w", err)
	}

	if len(paths) == 0 {
		if ctx.Config.Quiet {
			fmt.Println("no tracked VHDs")
		} else {
			ctx.Logger.Info("No tracked VHDs found")
			ctx.Logger.Info("Use 'vhdm attach' or 'vhdm mount' to attach a VHD")
		}
		return nil
	}

	var vhds []types.VHDInfo
	for _, path := range paths {
		info := getVHDStatus(ctx, path)
		vhds = append(vhds, info)
	}

	if ctx.Config.Quiet {
		for _, vhd := range vhds {
			status := strings.ToLower(string(vhd.State))
			if vhd.UUID != "" {
				fmt.Printf("%s (%s): %s\n", vhd.Path, vhd.UUID, status)
			} else {
				fmt.Printf("%s: %s\n", vhd.Path, status)
			}
		}
		return nil
	}

	printStatusTable(vhds)
	return nil
}

func showSingleStatus(ctx *AppContext, vhdPath, uuid, mountPoint string) error {
	// Find path if not provided
	if vhdPath == "" && uuid != "" {
		vhdPath, _ = ctx.Tracker.LookupPathByUUID(uuid)
	}
	if vhdPath == "" && mountPoint != "" {
		uuid, _ = ctx.WSL.FindUUIDByMountPoint(mountPoint)
		if uuid != "" {
			vhdPath, _ = ctx.Tracker.LookupPathByUUID(uuid)
		}
	}

	if vhdPath == "" {
		return fmt.Errorf("VHD not found in tracking")
	}

	info := getVHDStatus(ctx, vhdPath)

	if ctx.Config.Quiet {
		status := strings.ToLower(string(info.State))
		if info.UUID != "" {
			fmt.Printf("%s (%s): %s\n", info.Path, info.UUID, status)
		} else {
			fmt.Printf("%s: %s\n", info.Path, status)
		}
		return nil
	}

	printSingleStatus(info)
	return nil
}

func getVHDStatus(ctx *AppContext, path string) types.VHDInfo {
	info := types.VHDInfo{
		Path:  path,
		State: types.StateNotFound,
	}

	// Get from tracking
	entry, err := ctx.Tracker.GetEntry(path)
	if err == nil {
		info.UUID = entry.UUID
		info.DeviceName = entry.DeviceName
		info.MountPoint = strings.Join(entry.MountPoints, ",")
	}

	// Check VHD file exists
	wslPath := ctx.WSL.ConvertPath(path)
	if !ctx.WSL.FileExists(wslPath) {
		info.State = types.StateNotFound
		return info
	}

	// Check if attached
	if info.UUID != "" {
		attached, _ := ctx.WSL.IsAttached(info.UUID)
		if attached {
			info.State = types.StateAttachedFormatted
			
			// Check if mounted
			mp, _ := ctx.WSL.GetMountPoint(info.UUID)
			if mp != "" {
				info.State = types.StateMounted
				info.MountPoint = mp
			}

			// Get device info
			devName, _ := ctx.WSL.GetDeviceByUUID(info.UUID)
			if devName != "" {
				info.DeviceName = devName
			}
		} else {
			info.State = types.StateDetached
		}
	} else {
		// No UUID - might be unformatted or detached
		info.State = types.StateDetached
	}

	return info
}

func printStatusTable(vhds []types.VHDInfo) {
	fmt.Println()
	fmt.Println("Tracked VHD Disks")
	fmt.Println()
	
	// Calculate column widths
	colWidths := []int{40, 36, 8, 20, 12}
	headers := []string{"Path", "UUID", "Device", "Mount Point", "Status"}
	
	utils.PrintTableHeader(colWidths, headers)
	
	for _, vhd := range vhds {
		uuid := vhd.UUID
		if uuid == "" {
			uuid = "(none)"
		}
		dev := vhd.DeviceName
		if dev == "" {
			dev = "-"
		}
		mp := vhd.MountPoint
		if mp == "" {
			mp = "-"
		}
		utils.PrintTableRow(colWidths, vhd.Path, uuid, dev, mp, colorizeStatus(string(vhd.State)))
	}
	
	utils.PrintTableFooter(colWidths)
}

func printSingleStatus(info types.VHDInfo) {
	pairs := [][2]string{
		{"Path", info.Path},
	}
	
	if info.UUID != "" {
		pairs = append(pairs, [2]string{"UUID", info.UUID})
	}
	if info.DeviceName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + info.DeviceName})
	}
	if info.MountPoint != "" {
		pairs = append(pairs, [2]string{"Mount Point", info.MountPoint})
	}
	if info.FSAvail != "" {
		pairs = append(pairs, [2]string{"Available", info.FSAvail})
	}
	if info.FSUse != "" {
		pairs = append(pairs, [2]string{"Usage", info.FSUse})
	}
	pairs = append(pairs, [2]string{"Status", colorizeStatus(string(info.State))})
	
	utils.KeyValueTable("VHD Status", pairs, 14, 50)
}

func colorizeStatus(status string) string {
	switch types.VHDState(status) {
	case types.StateMounted:
		return utils.Green(status)
	case types.StateAttachedFormatted, types.StateAttachedUnformatted:
		return utils.Yellow(status)
	case types.StateDetached:
		return utils.Blue(status)
	case types.StateNotFound:
		return utils.Red(status)
	default:
		return status
	}
}

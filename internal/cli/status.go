package cli

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/internal/wsl"
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
		Long: `Show current VHD disk status including all WSL disks and tracked VHDs.

Without flags, shows all disks and tracked VHDs.
Use specific flags to query particular VHDs.
VHDs that no longer exist are automatically removed from tracking.`,
		Example: `  vhdm status
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
	// Auto-cleanup: remove tracked VHDs where file no longer exists
	fileExists := func(path string) bool {
		wslPath := ctx.WSL.ConvertPath(path)
		return ctx.WSL.FileExists(wslPath)
	}
	removed, err := ctx.Tracker.CleanupNonExistent(fileExists)
	if err != nil {
		ctx.Logger.Debug("Failed to cleanup non-existent VHDs: %v", err)
	}
	for _, path := range removed {
		ctx.Logger.Debug("Removed non-existent VHD from tracking: %s", path)
	}

	// Get all disks first (including system disks)
	allDisks, err := ctx.WSL.GetAllDisks()
	if err != nil {
		ctx.Logger.Debug("Failed to get disks: %v", err)
	}

	// Get tracked VHDs
	paths, err := ctx.Tracker.GetAllPaths()
	if err != nil {
		return fmt.Errorf("failed to get tracked VHDs: %w", err)
	}

	var vhds []types.VHDInfo
	for _, path := range paths {
		info := getVHDStatus(ctx, path)
		vhds = append(vhds, info)
	}

	if ctx.Config.Quiet {
		// Print all disks in quiet mode
		for _, disk := range allDisks {
			mps := filterEmptyMountPoints(disk.MountPoints)
			mp := strings.Join(mps, ",")
			if mp == "" {
				mp = "(not mounted)"
			}
			fmt.Printf("%s: %s at %s\n", disk.Name, disk.FSType, mp)
		}
		// Print tracked VHDs
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

	// Print all disks table
	if len(allDisks) > 0 {
		printAllDisksTable(allDisks)
	}

	// Print tracked VHDs table
	if len(vhds) > 0 {
		printStatusTable(vhds)
	} else {
		fmt.Println()
		ctx.Logger.Info("No tracked VHDs found")
		ctx.Logger.Info("Use 'vhdm attach' or 'vhdm mount' to attach a VHD")
	}

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
		info.LastSeen = entry.LastSeen
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

			// Get full disk info (mount points, available space, usage)
			diskInfo, _ := ctx.WSL.GetVHDInfo(info.UUID)
			if diskInfo != nil {
				if diskInfo.MountPoint != "" {
					info.State = types.StateMounted
					info.MountPoint = diskInfo.MountPoint
				}
				if diskInfo.DeviceName != "" {
					info.DeviceName = diskInfo.DeviceName
				}
				info.FSAvail = diskInfo.FSAvail
				info.FSUse = diskInfo.FSUse
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

// filterEmptyMountPoints removes empty strings from mount points
func filterEmptyMountPoints(mps []string) []string {
	var result []string
	for _, mp := range mps {
		if mp != "" {
			result = append(result, mp)
		}
	}
	return result
}

func printAllDisksTable(disks []wsl.BlockDevice) {
	fmt.Println()
	fmt.Println("WSL Attached Disks")
	fmt.Println()

	// Calculate column widths
	colWidths := []int{10, 36, 10, 40, 10, 8}
	headers := []string{"Device", "UUID", "Type", "Mount Points", "Available", "Use%"}

	utils.PrintTableHeader(colWidths, headers)

	for _, disk := range disks {
		uuid := disk.UUID
		if uuid == "" {
			uuid = "-"
		}
		fsType := disk.FSType
		if fsType == "" {
			fsType = "-"
		}
		// Get all non-empty mount points
		mps := filterEmptyMountPoints(disk.MountPoints)
		mp := "-"
		if len(mps) > 0 {
			mp = strings.Join(mps, ", ")
		}
		avail := disk.FSAvail
		if avail == "" {
			avail = "-"
		}
		useP := disk.FSUseP
		if useP == "" {
			useP = "-"
		}
		utils.PrintTableRow(colWidths, disk.Name, uuid, fsType, mp, avail, useP)
	}

	utils.PrintTableFooter(colWidths)
}

func printStatusTable(vhds []types.VHDInfo) {
	fmt.Println()
	fmt.Println("Tracked VHD Disks")
	fmt.Println()

	// Calculate column widths
	colWidths := []int{40, 36, 8, 20, 12, 20}
	headers := []string{"Path", "UUID", "Device", "Mount Point", "Status", "Last Seen"}

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
		// Format LastSeen timestamp (truncate to datetime)
		lastSeen := vhd.LastSeen
		if len(lastSeen) > 19 {
			lastSeen = lastSeen[:19]
		}
		if lastSeen == "" {
			lastSeen = "-"
		}
		utils.PrintTableRow(colWidths, vhd.Path, uuid, dev, mp, colorizeStatus(string(vhd.State)), lastSeen)
	}

	utils.PrintTableFooter(colWidths)
}

func printSingleStatus(info types.VHDInfo) {
	// Helper to show "-" for empty values
	valOrDash := func(s string) string {
		if s == "" {
			return "-"
		}
		return s
	}

	device := "-"
	if info.DeviceName != "" {
		device = "/dev/" + info.DeviceName
	}

	// Format LastSeen timestamp
	lastSeen := info.LastSeen
	if len(lastSeen) > 19 {
		lastSeen = lastSeen[:19]
	}

	pairs := [][2]string{
		{"Path", info.Path},
		{"UUID", valOrDash(info.UUID)},
		{"Device", device},
		{"Mount Point", valOrDash(info.MountPoint)},
		{"Available", valOrDash(info.FSAvail)},
		{"Usage", valOrDash(info.FSUse)},
		{"Last Seen", valOrDash(lastSeen)},
		{"Status", colorizeStatus(string(info.State))},
	}

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

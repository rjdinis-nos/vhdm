package cli

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/rjdinis/vhdm/internal/tracking"
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
		Example: `  vhdm status --all
  vhdm status --vhd-path C:/VMs/disk.vhdx`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runStatus(vhdPath, uuid, mountPoint, showAll)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
	cmd.Flags().StringVar(&uuid, "uuid", "", "VHD UUID")
	cmd.Flags().StringVar(&mountPoint, "mount-point", "", "Mount point path")
	cmd.Flags().BoolVar(&showAll, "all", false, "Show all attached VHDs")
	return cmd
}

func runStatus(vhdPath, uuid, mountPoint string, showAll bool) error {
	ctx := getContext()
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
	if !showAll && vhdPath == "" && uuid == "" && mountPoint == "" {
		fmt.Println("Usage: vhdm status [OPTIONS]")
		fmt.Println("\nOptions:")
		fmt.Println("  --vhd-path PATH    Show status for specific VHD")
		fmt.Println("  --uuid UUID        Show status for specific UUID")
		fmt.Println("  --mount-point PATH Show status for mount point")
		fmt.Println("  --all              Show all attached VHDs")
		return nil
	}
	ctx.Logger.Debug("Status operation starting")
	if showAll {
		return showAllStatus(ctx)
	}
	return showSingleStatus(ctx, vhdPath, uuid, mountPoint)
}

func showAllStatus(ctx *AppContext) error {
	mappings, err := ctx.Tracker.GetAllMappings()
	if err != nil {
		return fmt.Errorf("failed to get mappings: %w", err)
	}
	if len(mappings) == 0 {
		if ctx.Config.Quiet {
			fmt.Println("no VHDs tracked")
		} else {
			fmt.Println("No VHDs are currently tracked.")
		}
		return nil
	}
	if ctx.Config.Quiet {
		for path, m := range mappings {
			status := "tracked"
			if m.MountPoints != "" {
				status = "mounted"
			}
			fmt.Printf("%s (%s): %s\n", path, m.UUID, status)
		}
		return nil
	}
	utils.PrintTable("Tracked VHD Disks", []string{"Path", "UUID", "Device", "Mount", "Status"},
		buildStatusRows(mappings), 40, 36, 8, 15, 10)
	return nil
}

func showSingleStatus(ctx *AppContext, vhdPath, uuid, mountPoint string) error {
	var mapping *tracking.Mapping
	var normalizedPath string
	if vhdPath != "" {
		normalizedPath = utils.NormalizePath(vhdPath)
		mapping, _ = ctx.Tracker.GetMapping(vhdPath)
	} else if uuid != "" {
		path, _ := ctx.Tracker.LookupPathByUUID(uuid)
		if path != "" {
			normalizedPath = path
			mapping, _ = ctx.Tracker.GetMapping(path)
		}
	}
	if mapping == nil {
		if ctx.Config.Quiet {
			fmt.Println("not found")
		} else {
			fmt.Println("VHD not found in tracking file.")
		}
		return nil
	}
	if ctx.Config.Quiet {
		status := "tracked"
		if mapping.MountPoints != "" {
			status = "mounted"
		}
		fmt.Printf("%s (%s): %s\n", normalizedPath, mapping.UUID, status)
		return nil
	}
	pairs := [][2]string{{"Path", normalizedPath}}
	if mapping.UUID != "" {
		pairs = append(pairs, [2]string{"UUID", mapping.UUID})
	}
	if mapping.DevName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + mapping.DevName})
	}
	if mapping.MountPoints != "" {
		pairs = append(pairs, [2]string{"Mount Point", mapping.MountPoints})
	}
	status := "Tracked"
	if mapping.MountPoints != "" {
		status = "Mounted"
	}
	pairs = append(pairs, [2]string{"Status", status}, [2]string{"Last Attached", mapping.LastAttached})
	utils.KeyValueTable("VHD Disk Status", pairs, 14, 50)
	return nil
}

func buildStatusRows(mappings map[string]*tracking.Mapping) [][]string {
	rows := make([][]string, 0, len(mappings))
	for path, m := range mappings {
		status := "Tracked"
		if m.MountPoints != "" {
			status = "Mounted"
		}
		dev := "-"
		if m.DevName != "" {
			dev = m.DevName
		}
		uuid := "-"
		if m.UUID != "" {
			uuid = m.UUID
		}
		mp := "-"
		if m.MountPoints != "" {
			mp = m.MountPoints
		}
		rows = append(rows, []string{path, uuid, dev, mp, status})
	}
	return rows
}

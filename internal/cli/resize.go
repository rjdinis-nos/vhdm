package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/internal/validation"
	"github.com/rjdinis/vhdm/pkg/utils"
)

func newResizeCmd() *cobra.Command {
	var (
		vhdPath string
		newSize string
	)
	cmd := &cobra.Command{
		Use:   "resize",
		Short: "Resize a VHD file",
		Long: `Resize a VHD file to a new size.

This operation creates a new VHD with the specified size, copies all data
from the original VHD, and preserves the original as a backup (*_bkp.vhdx).

If the VHD is currently mounted or attached, it will be automatically
unmounted and detached before resizing, then re-mounted to the original
mount point after completion.

The process:
1. Unmounts and detaches the VHD if needed (saves mount point)
2. Creates a new VHD with the new size
3. Attaches both VHDs
4. Formats new VHD with same filesystem type
5. Mounts both to temporary directories
6. Copies data using rsync
7. Verifies file counts match
8. Unmounts and detaches both
9. Renames original to backup
10. Renames new to original name
11. Re-attaches and re-mounts to original mount point (if was mounted)`,
		Example: `  vhdm resize --vhd-path C:/VMs/disk.vhdx --size 20G
  vhdm resize --vhd-path C:/VMs/disk.vhdx --size 10G -y`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runResize(vhdPath, newSize)
		},
	}
	cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path (Windows format)")
	cmd.Flags().StringVar(&newSize, "size", "", "New VHD size (e.g., 10G, 20G)")
	cmd.MarkFlagRequired("vhd-path")
	cmd.MarkFlagRequired("size")
	return cmd
}

func runResize(vhdPath, newSize string) error {
	ctx := getContext()
	log := ctx.Logger

	// Validate inputs
	if err := validation.ValidateWindowsPath(vhdPath); err != nil {
		return &types.VHDError{Op: "resize", Path: vhdPath, Err: err}
	}
	if err := validation.ValidateSizeString(newSize); err != nil {
		return &types.VHDError{Op: "resize", Err: err}
	}

	log.Debug("Resize operation starting for: %s to size: %s", vhdPath, newSize)

	// Check if original file exists
	wslPath := ctx.WSL.ConvertPath(vhdPath)
	if !ctx.WSL.FileExists(wslPath) {
		return fmt.Errorf("VHD file not found: %s", vhdPath)
	}

	// Check if VHD is currently attached - unmount and detach if needed
	// Save original mount point to restore after resize
	var originalMountPoint string
	uuid, _ := ctx.Tracker.LookupUUIDByPath(vhdPath)
	if uuid != "" {
		attached, _ := ctx.WSL.IsAttached(uuid)
		if attached {
			mounted, _ := ctx.WSL.IsMounted(uuid)
			if mounted {
				log.Info("VHD is mounted, unmounting first...")
				originalMountPoint, _ = ctx.WSL.GetMountPoint(uuid)
				if originalMountPoint != "" {
					if err := ctx.WSL.Unmount(originalMountPoint); err != nil {
						return fmt.Errorf("failed to unmount VHD: %w", err)
					}
					log.Success("Unmounted from %s", originalMountPoint)
				}
			}
			log.Info("VHD is attached, detaching first...")
			if err := ctx.WSL.DetachVHD(vhdPath); err != nil {
				if !types.IsNotAttached(err) {
					return fmt.Errorf("failed to detach VHD: %w", err)
				}
			} else {
				log.Success("VHD detached")
			}
			// Remove mapping from tracking
			ctx.Tracker.RemoveMapping(vhdPath)
		}
	}

	// restoreOriginalMount re-attaches and re-mounts original VHD if it was mounted
	restoreOriginalMount := func() {
		if originalMountPoint == "" {
			return
		}
		log.Info("Restoring original VHD to %s...", originalMountPoint)
		// Re-attach original VHD
		_, err := ctx.WSL.AttachVHD(vhdPath)
		if err != nil {
			if !types.IsAlreadyAttached(err) {
				log.Warn("Failed to re-attach original VHD: %v", err)
				return
			}
		}
		// Re-mount to original mount point
		if err := ctx.WSL.MountByUUID(uuid, originalMountPoint); err != nil {
			log.Warn("Failed to re-mount original VHD: %v", err)
			return
		}
		// Get device name and update tracking
		devName, _ := ctx.WSL.GetDeviceByUUID(uuid)
		if err := ctx.Tracker.SaveMapping(vhdPath, uuid, originalMountPoint, devName); err != nil {
			log.Warn("Failed to update tracking: %v", err)
		}
		log.Success("Original VHD restored to %s", originalMountPoint)
	}

	// Confirm resize
	if !ctx.Config.Yes {
		log.Warn("This will resize: %s to %s", vhdPath, newSize)
		log.Warn("The original VHD will be preserved as a backup (*_bkp.vhdx)")
		log.Warn("Run with --yes to confirm")
		restoreOriginalMount()
		return fmt.Errorf("operation cancelled")
	}

	// Generate paths
	newVHDPath := generateNewVHDPath(vhdPath)
	backupVHDPath := generateBackupPath(vhdPath)
	newWSLPath := ctx.WSL.ConvertPath(newVHDPath)
	backupWSLPath := ctx.WSL.ConvertPath(backupVHDPath)

	// Check if backup already exists
	if ctx.WSL.FileExists(backupWSLPath) {
		restoreOriginalMount()
		return fmt.Errorf("backup file already exists: %s - please remove or rename it first", backupVHDPath)
	}

	// Create temporary mount points
	tmpOld, err := os.MkdirTemp("", "vhdm-resize-old-")
	if err != nil {
		restoreOriginalMount()
		return fmt.Errorf("failed to create temp mount point: %w", err)
	}
	defer os.RemoveAll(tmpOld)

	tmpNew, err := os.MkdirTemp("", "vhdm-resize-new-")
	if err != nil {
		restoreOriginalMount()
		return fmt.Errorf("failed to create temp mount point: %w", err)
	}
	defer os.RemoveAll(tmpNew)

	// Cleanup function for error cases
	cleanup := func() {
		log.Debug("Cleaning up...")
		// Try to unmount and detach both VHDs
		ctx.WSL.Unmount(tmpOld)
		ctx.WSL.Unmount(tmpNew)
		ctx.WSL.DetachVHD(vhdPath)
		ctx.WSL.DetachVHD(newVHDPath)
		// Remove new VHD on failure
		ctx.WSL.DeleteVHD(newWSLPath)
		// Restore original VHD to its mount point
		restoreOriginalMount()
	}

	log.Info("Creating new VHD: %s (%s)...", newVHDPath, newSize)
	if err := ctx.WSL.CreateVHD(newWSLPath, newSize); err != nil {
		restoreOriginalMount()
		return fmt.Errorf("failed to create new VHD: %w", err)
	}

	// Attach original VHD
	log.Info("Attaching original VHD...")
	oldDevices, err := ctx.WSL.GetBlockDevices()
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to get block devices: %w", err)
	}

	_, err = ctx.WSL.AttachVHD(vhdPath)
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to attach original VHD: %w", err)
	}

	oldDevName, err := ctx.WSL.DetectNewDevice(oldDevices)
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to detect original VHD device: %w", err)
	}
	log.Debug("Original VHD attached as /dev/%s", oldDevName)

	// Get UUID and filesystem type of original
	oldUUID, _ := ctx.WSL.GetUUIDByDevice(oldDevName)
	if oldUUID == "" {
		cleanup()
		return fmt.Errorf("original VHD is not formatted - cannot resize")
	}

	fsType, err := ctx.WSL.GetFilesystemType(oldDevName)
	if err != nil || fsType == "" {
		cleanup()
		return fmt.Errorf("failed to detect filesystem type of original VHD")
	}
	log.Debug("Original VHD filesystem: %s, UUID: %s", fsType, oldUUID)

	// Attach new VHD
	log.Info("Attaching new VHD...")
	newDevices, err := ctx.WSL.GetBlockDevices()
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to get block devices: %w", err)
	}

	_, err = ctx.WSL.AttachVHD(newVHDPath)
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to attach new VHD: %w", err)
	}

	newDevName, err := ctx.WSL.DetectNewDevice(newDevices)
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to detect new VHD device: %w", err)
	}
	log.Debug("New VHD attached as /dev/%s", newDevName)

	// Format new VHD
	log.Info("Formatting new VHD with %s...", fsType)
	newUUID, err := ctx.WSL.Format(newDevName, fsType)
	if err != nil {
		cleanup()
		return fmt.Errorf("failed to format new VHD: %w", err)
	}
	log.Debug("New VHD UUID: %s", newUUID)

	// Mount both VHDs
	log.Info("Mounting VHDs for data transfer...")
	if err := ctx.WSL.MountByUUID(oldUUID, tmpOld); err != nil {
		cleanup()
		return fmt.Errorf("failed to mount original VHD: %w", err)
	}

	if err := ctx.WSL.MountByUUID(newUUID, tmpNew); err != nil {
		cleanup()
		return fmt.Errorf("failed to mount new VHD: %w", err)
	}

	// Get file count before copy
	oldFileCount, err := ctx.WSL.CountFiles(tmpOld)
	if err != nil {
		log.Warn("Could not count files in source: %v", err)
		oldFileCount = -1
	}
	log.Debug("Source file count: %d", oldFileCount)

	// Copy data using rsync
	log.Info("Copying data (this may take a while)...")
	if err := ctx.WSL.RsyncCopy(tmpOld, tmpNew); err != nil {
		cleanup()
		return fmt.Errorf("failed to copy data: %w", err)
	}
	log.Success("Data copy complete")

	// Verify file counts match
	if oldFileCount > 0 {
		newFileCount, err := ctx.WSL.CountFiles(tmpNew)
		if err != nil {
			log.Warn("Could not verify file count: %v", err)
		} else {
			log.Debug("Destination file count: %d", newFileCount)
			if newFileCount != oldFileCount {
				log.Warn("File count mismatch: source=%d, dest=%d", oldFileCount, newFileCount)
				log.Warn("Proceeding anyway - please verify data manually")
			} else {
				log.Success("File count verified: %d files", newFileCount)
			}
		}
	}

	// Unmount both VHDs
	log.Info("Unmounting VHDs...")
	if err := ctx.WSL.Unmount(tmpOld); err != nil {
		log.Warn("Failed to unmount original: %v", err)
	}
	if err := ctx.WSL.Unmount(tmpNew); err != nil {
		log.Warn("Failed to unmount new: %v", err)
	}

	// Detach both VHDs
	log.Info("Detaching VHDs...")
	if err := ctx.WSL.DetachVHD(vhdPath); err != nil {
		log.Warn("Failed to detach original: %v", err)
	}
	if err := ctx.WSL.DetachVHD(newVHDPath); err != nil {
		log.Warn("Failed to detach new: %v", err)
	}

	// Rename original to backup
	log.Info("Creating backup of original VHD...")
	if err := ctx.WSL.RenameFile(wslPath, backupWSLPath); err != nil {
		return fmt.Errorf("failed to create backup: %w", err)
	}

	// Rename new to original name
	log.Info("Finalizing resize...")
	if err := ctx.WSL.RenameFile(newWSLPath, wslPath); err != nil {
		// Try to restore original
		ctx.WSL.RenameFile(backupWSLPath, wslPath)
		return fmt.Errorf("failed to rename new VHD: %w", err)
	}

	// Update tracking with new UUID
	if err := ctx.Tracker.SaveMapping(vhdPath, newUUID, "", ""); err != nil {
		log.Warn("Failed to update tracking: %v", err)
	}

	// Re-mount to original mount point if it was originally mounted
	var finalDevName string
	if originalMountPoint != "" {
		log.Info("Re-attaching resized VHD...")
		beforeDevices, err := ctx.WSL.GetBlockDevices()
		if err != nil {
			log.Warn("Failed to get block devices for re-attach: %v", err)
		} else {
			_, err = ctx.WSL.AttachVHD(vhdPath)
			if err != nil {
				log.Warn("Failed to re-attach VHD: %v", err)
			} else {
				finalDevName, err = ctx.WSL.DetectNewDevice(beforeDevices)
				if err != nil {
					log.Warn("Failed to detect device after re-attach: %v", err)
				} else {
					log.Success("VHD re-attached as /dev/%s", finalDevName)

					log.Info("Re-mounting to %s...", originalMountPoint)
					if err := ctx.WSL.MountByUUID(newUUID, originalMountPoint); err != nil {
						log.Warn("Failed to re-mount VHD: %v", err)
					} else {
						log.Success("VHD re-mounted to %s", originalMountPoint)
						// Update tracking with mount point and device
						ctx.Tracker.SaveMapping(vhdPath, newUUID, originalMountPoint, finalDevName)
					}
				}
			}
		}
	}

	// Output
	if ctx.Config.Quiet {
		fmt.Printf("%s (%s): resized to %s\n", vhdPath, newUUID, newSize)
		return nil
	}

	log.Success("VHD resized successfully!")

	pairs := [][2]string{
		{"Path", vhdPath},
		{"New Size", newSize},
		{"New UUID", newUUID},
		{"Old UUID", oldUUID},
		{"Backup", backupVHDPath},
	}
	if originalMountPoint != "" {
		pairs = append(pairs, [2]string{"Mount Point", originalMountPoint})
	}
	if finalDevName != "" {
		pairs = append(pairs, [2]string{"Device", "/dev/" + finalDevName})
	}
	pairs = append(pairs, [2]string{"Status", "resized"})
	utils.KeyValueTable("Resize Result", pairs, 14, 50)

	fmt.Println()
	log.Info("Original VHD preserved as: %s", backupVHDPath)
	log.Info("Please verify the resized VHD works correctly, then delete the backup manually")

	return nil
}

// generateNewVHDPath generates a temporary path for the new VHD
func generateNewVHDPath(originalPath string) string {
	ext := filepath.Ext(originalPath)
	base := strings.TrimSuffix(originalPath, ext)
	return base + "_new" + ext
}

// generateBackupPath generates a backup path for the original VHD
func generateBackupPath(originalPath string) string {
	ext := filepath.Ext(originalPath)
	base := strings.TrimSuffix(originalPath, ext)
	return base + "_bkp" + ext
}

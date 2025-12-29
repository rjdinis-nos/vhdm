// Package wsl provides WSL-specific operations for VHD management.
package wsl

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/rjdinis/vhdm/internal/logging"
	"github.com/rjdinis/vhdm/internal/types"
	"github.com/rjdinis/vhdm/pkg/utils"
)

// Client handles WSL operations
type Client struct {
	logger           *logging.Logger
	sleepAfterAttach time.Duration
	detachTimeout    time.Duration
}

// NewClient creates a new WSL client
func NewClient(logger *logging.Logger, sleepAfterAttach, detachTimeout time.Duration) *Client {
	return &Client{
		logger:           logger,
		sleepAfterAttach: sleepAfterAttach,
		detachTimeout:    detachTimeout,
	}
}

// ConvertPath converts Windows path to WSL path
func (c *Client) ConvertPath(winPath string) string {
	return utils.ConvertWindowsToWSLPath(winPath)
}

// FileExists checks if a file exists at the WSL path
func (c *Client) FileExists(wslPath string) bool {
	_, err := os.Stat(wslPath)
	return err == nil
}

// lsblkOutput represents the JSON output from lsblk
type lsblkOutput struct {
	BlockDevices []BlockDevice `json:"blockdevices"`
}

// BlockDevice represents a block device from lsblk output
type BlockDevice struct {
	Name        string   `json:"name"`
	UUID        string   `json:"uuid"`
	FSType      string   `json:"fstype"`
	MountPoints []string `json:"mountpoints"`
	FSAvail     string   `json:"fsavail"`
	FSUseP      string   `json:"fsuse%"`
	Size        string   `json:"size"`
}

// dynamicVHDPattern matches dynamically attached VHD devices (sd[d-z] and beyond)
var dynamicVHDPattern = regexp.MustCompile(`^sd[d-z][a-z]*$`)

// GetBlockDevices returns list of block device names
func (c *Client) GetBlockDevices() ([]string, error) {
	c.logger.Debug("Running: lsblk -J")

	cmd := exec.Command("lsblk", "-J")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("lsblk failed: %w", err)
	}

	var result lsblkOutput
	if err := json.Unmarshal(output, &result); err != nil {
		return nil, fmt.Errorf("failed to parse lsblk output: %w", err)
	}

	devices := make([]string, 0, len(result.BlockDevices))
	for _, dev := range result.BlockDevices {
		devices = append(devices, dev.Name)
	}

	return devices, nil
}

// GetBlockDevicesWithInfo returns detailed block device information
func (c *Client) GetBlockDevicesWithInfo() ([]BlockDevice, error) {
	c.logger.Debug("Running: lsblk -f -o NAME,UUID,FSTYPE,MOUNTPOINTS,FSAVAIL,FSUSE%,SIZE -J")

	cmd := exec.Command("lsblk", "-f", "-o", "NAME,UUID,FSTYPE,MOUNTPOINTS,FSAVAIL,FSUSE%,SIZE", "-J")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("lsblk failed: %w", err)
	}

	var result lsblkOutput
	if err := json.Unmarshal(output, &result); err != nil {
		return nil, fmt.Errorf("failed to parse lsblk output: %w", err)
	}

	return result.BlockDevices, nil
}

// GetAllDisks returns all block devices (including system disks)
func (c *Client) GetAllDisks() ([]BlockDevice, error) {
	return c.GetBlockDevicesWithInfo()
}

// GetUUIDByDevice gets the UUID of a device
func (c *Client) GetUUIDByDevice(devName string) (string, error) {
	// Remove /dev/ prefix if present
	devName = strings.TrimPrefix(devName, "/dev/")

	c.logger.Debug("Running: sudo blkid -s UUID -o value /dev/%s", devName)

	cmd := exec.Command("sudo", "blkid", "-s", "UUID", "-o", "value", "/dev/"+devName)
	output, err := cmd.Output()
	if err != nil {
		// Device may not be formatted
		return "", nil
	}

	uuid := strings.TrimSpace(string(output))
	if uuid == "" {
		return "", nil
	}

	return uuid, nil
}

// GetDeviceByUUID gets device name by UUID
func (c *Client) GetDeviceByUUID(uuid string) (string, error) {
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return "", err
	}

	for _, dev := range devices {
		if dev.UUID == uuid {
			return dev.Name, nil
		}
	}

	return "", nil
}

// IsAttached checks if a VHD is attached by UUID
func (c *Client) IsAttached(uuid string) (bool, error) {
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return false, err
	}

	for _, dev := range devices {
		if dev.UUID == uuid {
			return true, nil
		}
	}

	return false, nil
}

// IsMounted checks if a VHD is mounted by UUID
func (c *Client) IsMounted(uuid string) (bool, error) {
	mp, err := c.GetMountPoint(uuid)
	if err != nil {
		return false, err
	}
	return mp != "", nil
}

// GetMountPoint gets the mount point for a UUID
func (c *Client) GetMountPoint(uuid string) (string, error) {
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return "", err
	}

	for _, dev := range devices {
		if dev.UUID == uuid && len(dev.MountPoints) > 0 {
			for _, mp := range dev.MountPoints {
				if mp != "" {
					return mp, nil
				}
			}
		}
	}

	return "", nil
}

// GetUUIDByMountPoint gets the UUID for a filesystem mounted at a mount point
func (c *Client) GetUUIDByMountPoint(mountPoint string) (string, error) {
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return "", err
	}

	for _, dev := range devices {
		if len(dev.MountPoints) > 0 {
			for _, mp := range dev.MountPoints {
				if mp == mountPoint && dev.UUID != "" {
					return dev.UUID, nil
				}
			}
		}
	}

	return "", nil
}

// GetVHDInfo gets information about a VHD by UUID
func (c *Client) GetVHDInfo(uuid string) (*types.VHDInfo, error) {
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return nil, err
	}

	for _, dev := range devices {
		if dev.UUID == uuid {
			info := &types.VHDInfo{
				UUID:       uuid,
				DeviceName: dev.Name,
				FSAvail:    dev.FSAvail,
				FSUse:      dev.FSUseP,
			}

			if len(dev.MountPoints) > 0 {
				for _, mp := range dev.MountPoints {
					if mp != "" {
						info.MountPoint = mp
						info.State = types.StateMounted
						break
					}
				}
			}

			if info.State != types.StateMounted {
				info.State = types.StateAttachedFormatted
			}

			return info, nil
		}
	}

	return nil, nil
}

// CountDynamicVHDs counts non-system attached VHDs
func (c *Client) CountDynamicVHDs() (int, error) {
	devices, err := c.GetBlockDevices()
	if err != nil {
		return 0, err
	}

	count := 0
	for _, dev := range devices {
		if dynamicVHDPattern.MatchString(dev) {
			count++
		}
	}

	return count, nil
}

// FindDynamicVHDUUID finds UUID of the single dynamic VHD
// WARNING: Only use when CountDynamicVHDs() returns 1
func (c *Client) FindDynamicVHDUUID() (string, error) {
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return "", err
	}

	for _, dev := range devices {
		if dynamicVHDPattern.MatchString(dev.Name) && dev.UUID != "" {
			return dev.UUID, nil
		}
	}

	return "", types.ErrVHDNotFound
}

// FindUUIDByPath finds UUID for a VHD path with multi-VHD safety
func (c *Client) FindUUIDByPath(path string) (string, error) {
	// Check if file exists
	wslPath := c.ConvertPath(path)
	if !c.FileExists(wslPath) {
		return "", types.ErrVHDNotFound
	}

	count, err := c.CountDynamicVHDs()
	if err != nil {
		return "", err
	}

	if count > 1 {
		return "", types.ErrMultipleVHDs
	}

	if count == 0 {
		return "", types.ErrVHDNotAttached
	}

	// Safe: exactly one VHD
	return c.FindDynamicVHDUUID()
}

// DetectNewDevice detects a newly attached device by comparing snapshots
func (c *Client) DetectNewDevice(oldDevices []string) (string, error) {
	// Build map of old dynamic VHD devices
	oldDevMap := make(map[string]bool)
	for _, dev := range oldDevices {
		if dynamicVHDPattern.MatchString(dev) {
			oldDevMap[dev] = true
		}
	}

	c.logger.Debug("Old VHD devices: %v", oldDevMap)

	// Sleep to let kernel recognize device
	time.Sleep(c.sleepAfterAttach)

	// Get new device list
	newDevices, err := c.GetBlockDevices()
	if err != nil {
		return "", err
	}

	// Find new device
	for _, dev := range newDevices {
		if !oldDevMap[dev] && dynamicVHDPattern.MatchString(dev) {
			c.logger.Debug("New device detected: %s", dev)
			return dev, nil
		}
	}

	return "", types.ErrDeviceNotFound
}

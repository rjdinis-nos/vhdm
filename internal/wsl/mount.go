package wsl

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// CreateMountPoint creates a mount point directory
func (c *Client) CreateMountPoint(path string) error {
	c.logger.Debug("Creating mount point: %s", path)
	
	if err := os.MkdirAll(path, 0755); err != nil {
		return fmt.Errorf("failed to create mount point: %w", err)
	}
	
	return nil
}

// MountByUUID mounts a filesystem by UUID to a mount point
func (c *Client) MountByUUID(uuid, mountPoint string) error {
	c.logger.Debug("Running: sudo mount UUID=%s %s", uuid, mountPoint)
	
	// Create mount point if needed
	if err := c.CreateMountPoint(mountPoint); err != nil {
		return err
	}
	
	// Mount
	cmd := exec.Command("sudo", "mount", "UUID="+uuid, mountPoint)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("mount failed: %s", strings.TrimSpace(string(output)))
	}
	
	// Set permissions
	c.logger.Debug("Setting permissions on mount point")
	
	if err := exec.Command("sudo", "chmod", "755", mountPoint).Run(); err != nil {
		c.logger.Warn("Failed to set permissions: %v", err)
	}
	
	// Get current user
	user := os.Getenv("USER")
	if user != "" {
		if err := exec.Command("sudo", "chown", user+":"+user, mountPoint).Run(); err != nil {
			c.logger.Warn("Failed to set owner: %v", err)
		}
	}
	
	return nil
}

// Unmount unmounts a filesystem from a mount point
func (c *Client) Unmount(mountPoint string) error {
	c.logger.Debug("Running: sudo umount %s", mountPoint)
	
	cmd := exec.Command("sudo", "umount", mountPoint)
	output, err := cmd.CombinedOutput()
	if err != nil {
		outStr := strings.TrimSpace(string(output))
		
		// Try to show processes using the mount point
		c.logger.Error("Failed to unmount: %s", outStr)
		c.logger.Info("Checking for processes using the mount point...")
		
		lsofCmd := exec.Command("sudo", "lsof", "+D", mountPoint)
		lsofOutput, _ := lsofCmd.CombinedOutput()
		if len(lsofOutput) > 0 {
			c.logger.Info("Processes using mount point:\n%s", string(lsofOutput))
		} else {
			c.logger.Info("No processes found (or lsof not available)")
		}
		
		c.logger.Info("Tip: You can try force unmount with: sudo umount -l %s", mountPoint)
		
		return fmt.Errorf("unmount failed: %s", outStr)
	}
	
	return nil
}

// ForceUnmount performs a lazy unmount
func (c *Client) ForceUnmount(mountPoint string) error {
	c.logger.Debug("Running: sudo umount -l %s", mountPoint)
	
	cmd := exec.Command("sudo", "umount", "-l", mountPoint)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("force unmount failed: %s", strings.TrimSpace(string(output)))
	}
	
	return nil
}

// FindMountPointByUUID finds mount point for a UUID from system
func (c *Client) FindMountPointByUUID(uuid string) (string, error) {
	return c.GetMountPoint(uuid)
}

// FindUUIDByMountPoint finds UUID for a mount point
func (c *Client) FindUUIDByMountPoint(mountPoint string) (string, error) {
	// Strip trailing slash for comparison
	mountPoint = strings.TrimSuffix(mountPoint, "/")
	
	devices, err := c.GetBlockDevicesWithInfo()
	if err != nil {
		return "", err
	}
	
	for _, dev := range devices {
		for _, mp := range dev.MountPoints {
			if strings.TrimSuffix(mp, "/") == mountPoint {
				return dev.UUID, nil
			}
		}
	}
	
	return "", nil
}

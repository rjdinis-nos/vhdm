package wsl

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Format formats a device with a filesystem
func (c *Client) Format(devName, fsType string) (string, error) {
	// Remove /dev/ prefix if present
	devName = strings.TrimPrefix(devName, "/dev/")
	devicePath := "/dev/" + devName
	
	c.logger.Debug("Running: sudo mkfs -t %s %s", fsType, devicePath)
	
	cmd := exec.Command("sudo", "mkfs", "-t", fsType, devicePath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("format failed: %s", strings.TrimSpace(string(output)))
	}
	
	// Wait for system to update UUID info
	time.Sleep(1 * time.Second)
	
	// Get new UUID
	uuid, err := c.GetUUIDByDevice(devName)
	if err != nil {
		return "", fmt.Errorf("failed to get UUID after format: %w", err)
	}
	
	if uuid == "" {
		return "", fmt.Errorf("no UUID found after formatting")
	}
	
	return uuid, nil
}

// CreateVHD creates a new VHD file using qemu-img
func (c *Client) CreateVHD(wslPath, size string) error {
	c.logger.Debug("Running: qemu-img create -f vhdx %s %s", wslPath, size)
	
	cmd := exec.Command("qemu-img", "create", "-f", "vhdx", wslPath, size)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("qemu-img create failed: %s", strings.TrimSpace(string(output)))
	}
	
	return nil
}

// DeleteVHD deletes a VHD file
func (c *Client) DeleteVHD(wslPath string) error {
	c.logger.Debug("Deleting VHD file: %s", wslPath)
	
	cmd := exec.Command("rm", "-f", wslPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("delete failed: %s", strings.TrimSpace(string(output)))
	}
	
	return nil
}

// IsFormatted checks if a device is formatted (has a filesystem)
func (c *Client) IsFormatted(devName string) (bool, error) {
	uuid, err := c.GetUUIDByDevice(devName)
	if err != nil {
		return false, err
	}
	return uuid != "", nil
}

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

// GetFilesystemType returns the filesystem type of a device
func (c *Client) GetFilesystemType(devName string) (string, error) {
	devName = strings.TrimPrefix(devName, "/dev/")

	c.logger.Debug("Running: sudo blkid -s TYPE -o value /dev/%s", devName)

	cmd := exec.Command("sudo", "blkid", "-s", "TYPE", "-o", "value", "/dev/"+devName)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get filesystem type: %w", err)
	}

	fsType := strings.TrimSpace(string(output))
	return fsType, nil
}

// RenameFile renames a file
func (c *Client) RenameFile(oldPath, newPath string) error {
	c.logger.Debug("Renaming: %s -> %s", oldPath, newPath)

	cmd := exec.Command("mv", oldPath, newPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("rename failed: %s", strings.TrimSpace(string(output)))
	}

	return nil
}

// CountFiles counts the number of files in a directory recursively
func (c *Client) CountFiles(path string) (int, error) {
	c.logger.Debug("Counting files in: %s", path)

	cmd := exec.Command("sudo", "find", path, "-type", "f")
	output, err := cmd.Output()
	if err != nil {
		return 0, fmt.Errorf("failed to count files: %w", err)
	}

	// Count lines in output
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return 0, nil
	}
	return len(lines), nil
}

// RsyncCopy copies data from source to destination using rsync
func (c *Client) RsyncCopy(src, dst string) error {
	// Ensure paths end with / for rsync to copy contents
	if !strings.HasSuffix(src, "/") {
		src = src + "/"
	}
	if !strings.HasSuffix(dst, "/") {
		dst = dst + "/"
	}

	c.logger.Debug("Running: sudo rsync -aHAX --info=progress2 %s %s", src, dst)

	cmd := exec.Command("sudo", "rsync", "-aHAX", "--info=progress2", src, dst)
	cmd.Stdout = nil // Don't capture stdout to allow progress display
	cmd.Stderr = nil
	
	// Run rsync and show progress
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("rsync failed: %w", err)
	}

	return nil
}

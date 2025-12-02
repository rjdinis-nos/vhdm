package wsl

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/rjdinis/vhdm/internal/types"
)

// EnsureInterop ensures WSL interop is enabled
func (c *Client) EnsureInterop() error {
	interopFile := "/proc/sys/fs/binfmt_misc/WSLInterop"
	
	if c.FileExists(interopFile) {
		c.logger.Debug("WSL interop is enabled")
		return nil
	}
	
	c.logger.Warn("WSL interop not enabled, attempting to enable...")
	
	// Try to enable interop
	cmd := exec.Command("sudo", "sh", "-c",
		`echo ":WSLInterop:M::MZ::/init:PF" > /proc/sys/fs/binfmt_misc/register`)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to enable WSL interop: %w", err)
	}
	
	c.logger.Success("WSL interop enabled")
	return nil
}

// AttachVHD attaches a VHD to WSL
func (c *Client) AttachVHD(path string) (*types.AttachResult, error) {
	if err := c.EnsureInterop(); err != nil {
		return nil, err
	}
	
	c.logger.Debug("Running: wsl.exe --mount --vhd %q --bare", path)
	
	cmd := exec.Command("wsl.exe", "--mount", "--vhd", path, "--bare")
	output, err := cmd.CombinedOutput()
	
	// Clean null bytes from output
	output = bytes.ReplaceAll(output, []byte{0}, []byte{})
	outStr := strings.TrimSpace(string(output))
	
	if err != nil {
		// Check for already attached error
		if strings.Contains(outStr, "WSL_E_USER_VHD_ALREADY_ATTACHED") ||
			strings.Contains(outStr, "already attached") ||
			strings.Contains(outStr, "already mounted") {
			return nil, types.ErrVHDAlreadyAttached
		}
		return nil, fmt.Errorf("wsl.exe attach failed: %s", outStr)
	}
	
	return &types.AttachResult{WasNew: true}, nil
}

// DetachVHD detaches a VHD from WSL
func (c *Client) DetachVHD(path string) error {
	if err := c.EnsureInterop(); err != nil {
		return err
	}
	
	c.logger.Debug("Running: wsl.exe --unmount %q", path)
	
	ctx, cancel := context.WithTimeout(context.Background(), c.detachTimeout)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "wsl.exe", "--unmount", path)
	output, err := cmd.CombinedOutput()
	
	// Clean null bytes
	output = bytes.ReplaceAll(output, []byte{0}, []byte{})
	outStr := strings.TrimSpace(string(output))
	
	if ctx.Err() == context.DeadlineExceeded {
		return types.ErrDetachTimeout
	}
	
	if err != nil {
		if strings.Contains(outStr, "ERROR_FILE_NOT_FOUND") {
			return types.ErrVHDNotAttached
		}
		return fmt.Errorf("wsl.exe unmount failed: %s", outStr)
	}
	
	return nil
}

// DeviceExists checks if a device exists
func (c *Client) DeviceExists(devName string) bool {
	devName = strings.TrimPrefix(devName, "/dev/")
	
	devices, err := c.GetBlockDevices()
	if err != nil {
		return false
	}
	
	for _, dev := range devices {
		if dev == devName {
			return true
		}
	}
	
	return false
}

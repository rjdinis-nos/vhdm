// Package validation provides input validation functions.
package validation

import (
	"fmt"
	"regexp"
	"strings"
)

const (
	maxPathLength = 4096
)

var (
	// Windows path: C:/ or C:\
	windowsPathRe = regexp.MustCompile(`^[A-Za-z]:[/\\]`)
	// UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	uuidRe = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	// Device name: sd[a-z]+
	deviceNameRe = regexp.MustCompile(`^sd[a-z]+$`)
	// Size string: number with optional unit
	sizeRe = regexp.MustCompile(`^[0-9]+(\.[0-9]+)?[KMGT]?[B]?$`)
	// Dangerous shell characters
	dangerousChars = regexp.MustCompile("[$`;&|<>\"'*?\\[\\]!~]")
)

// ValidateWindowsPath validates a Windows path format
func ValidateWindowsPath(path string) error {
	if path == "" {
		return fmt.Errorf("path cannot be empty")
	}
	if len(path) > maxPathLength {
		return fmt.Errorf("path too long")
	}
	if !windowsPathRe.MatchString(path) {
		return fmt.Errorf("invalid Windows path format")
	}
	if dangerousChars.MatchString(path) {
		return fmt.Errorf("path contains invalid characters")
	}
	if strings.Contains(path, "..") {
		return fmt.Errorf("path traversal not allowed")
	}
	return nil
}

// ValidateUUID validates a UUID format
func ValidateUUID(uuid string) error {
	if uuid == "" {
		return fmt.Errorf("UUID cannot be empty")
	}
	if !uuidRe.MatchString(uuid) {
		return fmt.Errorf("invalid UUID format")
	}
	return nil
}

// ValidateMountPoint validates a mount point path
func ValidateMountPoint(path string) error {
	if path == "" {
		return fmt.Errorf("mount point cannot be empty")
	}
	if !strings.HasPrefix(path, "/") {
		return fmt.Errorf("mount point must be absolute path")
	}
	if len(path) > maxPathLength {
		return fmt.Errorf("mount point path too long")
	}
	if dangerousChars.MatchString(path) {
		return fmt.Errorf("mount point contains invalid characters")
	}
	if strings.Contains(path, "..") {
		return fmt.Errorf("path traversal not allowed")
	}
	return nil
}

// ValidateDeviceName validates a device name (e.g., sdd, sde)
func ValidateDeviceName(name string) error {
	if name == "" {
		return fmt.Errorf("device name cannot be empty")
	}
	// Remove /dev/ prefix if present
	name = strings.TrimPrefix(name, "/dev/")
	if !deviceNameRe.MatchString(name) {
		return fmt.Errorf("invalid device name format")
	}
	return nil
}

// ValidateSizeString validates a size string (e.g., "5G", "500M")
func ValidateSizeString(size string) error {
	if size == "" {
		return fmt.Errorf("size cannot be empty")
	}
	size = strings.ToUpper(size)
	if !sizeRe.MatchString(size) {
		return fmt.Errorf("invalid size format (use e.g., 5G, 500M)")
	}
	return nil
}

// ValidateFilesystemType validates a filesystem type
func ValidateFilesystemType(fsType string) error {
	allowed := map[string]bool{
		"ext2": true, "ext3": true, "ext4": true,
		"xfs": true, "btrfs": true,
	}
	if !allowed[fsType] {
		return fmt.Errorf("unsupported filesystem type: %s (use ext2, ext3, ext4, xfs, btrfs)", fsType)
	}
	return nil
}

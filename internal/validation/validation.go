// Package validation provides input validation functions for vhdm.
package validation

import (
	"errors"
	"regexp"
	"strings"
)

var (
	ErrEmptyInput         = errors.New("input is empty")
	ErrInvalidWindowsPath = errors.New("invalid Windows path format")
	ErrInvalidUUID        = errors.New("invalid UUID format")
	ErrInvalidMountPoint  = errors.New("invalid mount point format")
	ErrInvalidDeviceName  = errors.New("invalid device name format")
	ErrInvalidSize        = errors.New("invalid size format")
	ErrInvalidFilesystem  = errors.New("invalid filesystem type")
	ErrDangerousPath      = errors.New("path contains dangerous characters")
	ErrPathTraversal      = errors.New("path contains traversal patterns")
	ErrPathTooLong        = errors.New("path exceeds maximum length")
)

var (
	windowsPathPattern = regexp.MustCompile(`^[A-Za-z]:[/\\]`)
	uuidPattern        = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	deviceNamePattern  = regexp.MustCompile(`^sd[a-z]+$`)
	sizePattern        = regexp.MustCompile(`(?i)^[0-9]+(\.[0-9]+)?[KMGT]?B?$`)
	dangerousChars     = regexp.MustCompile("[" + "`" + `$();|&<>"'*?\[\]!~]`)
)

var allowedFilesystems = map[string]bool{
	"ext2": true, "ext3": true, "ext4": true, "xfs": true,
	"btrfs": true, "ntfs": true, "vfat": true, "exfat": true,
}

const MaxPathLength = 4096

func ValidateWindowsPath(path string) error {
	if path == "" {
		return ErrEmptyInput
	}
	if len(path) > MaxPathLength {
		return ErrPathTooLong
	}
	if !windowsPathPattern.MatchString(path) {
		return ErrInvalidWindowsPath
	}
	if dangerousChars.MatchString(path) {
		return ErrDangerousPath
	}
	if strings.Contains(path, "..") {
		return ErrPathTraversal
	}
	for _, r := range path {
		if r < 32 || r == 127 {
			return ErrDangerousPath
		}
	}
	return nil
}

func ValidateUUID(uuid string) error {
	if uuid == "" {
		return ErrEmptyInput
	}
	if len(uuid) != 36 {
		return ErrInvalidUUID
	}
	if !uuidPattern.MatchString(uuid) {
		return ErrInvalidUUID
	}
	return nil
}

func ValidateMountPoint(path string) error {
	if path == "" {
		return ErrEmptyInput
	}
	if len(path) > MaxPathLength {
		return ErrPathTooLong
	}
	if !strings.HasPrefix(path, "/") {
		return ErrInvalidMountPoint
	}
	if dangerousChars.MatchString(path) {
		return ErrDangerousPath
	}
	if strings.Contains(path, "..") {
		return ErrPathTraversal
	}
	if path != strings.TrimSpace(path) {
		return ErrDangerousPath
	}
	return nil
}

func ValidateDeviceName(name string) error {
	if name == "" {
		return ErrEmptyInput
	}
	if len(name) > 10 {
		return ErrInvalidDeviceName
	}
	if !deviceNamePattern.MatchString(name) {
		return ErrInvalidDeviceName
	}
	return nil
}

func ValidateSizeString(size string) error {
	if size == "" {
		return ErrEmptyInput
	}
	if len(size) > 20 {
		return ErrInvalidSize
	}
	if !sizePattern.MatchString(size) {
		return ErrInvalidSize
	}
	return nil
}

func ValidateFilesystemType(fsType string) error {
	if fsType == "" {
		return ErrEmptyInput
	}
	if !allowedFilesystems[strings.ToLower(fsType)] {
		return ErrInvalidFilesystem
	}
	return nil
}

func SanitizeString(input string) string {
	var result strings.Builder
	for _, r := range input {
		if r >= 32 && r != 127 {
			result.WriteRune(r)
		}
	}
	return result.String()
}

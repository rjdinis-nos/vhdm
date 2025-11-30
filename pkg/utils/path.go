// Package utils provides utility functions for vhdm.
package utils

import "strings"

// ConvertWindowsToWSLPath converts a Windows path to WSL path format.
func ConvertWindowsToWSLPath(winPath string) string {
	if len(winPath) < 2 {
		return winPath
	}
	path := strings.ReplaceAll(winPath, "\\", "/")
	if len(path) >= 2 && path[1] == ':' {
		drive := strings.ToLower(string(path[0]))
		return "/mnt/" + drive + path[2:]
	}
	return path
}

// NormalizePath normalizes a Windows path for consistent tracking.
func NormalizePath(path string) string {
	path = strings.ReplaceAll(path, "\\", "/")
	return strings.ToLower(path)
}

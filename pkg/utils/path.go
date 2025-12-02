// Package utils provides utility functions.
package utils

import "strings"

// ConvertWindowsToWSLPath converts a Windows path to WSL path
// C:/path/to/file -> /mnt/c/path/to/file
func ConvertWindowsToWSLPath(winPath string) string {
	if winPath == "" {
		return ""
	}

	path := strings.ReplaceAll(winPath, "\\", "/")
	if len(path) >= 2 && path[1] == ':' {
		drive := strings.ToLower(string(path[0]))
		path = "/mnt/" + drive + path[2:]
	}
	return path
}

// NormalizePath normalizes a Windows path for tracking
func NormalizePath(path string) string {
	return strings.ToLower(strings.ReplaceAll(path, "\\", "/"))
}

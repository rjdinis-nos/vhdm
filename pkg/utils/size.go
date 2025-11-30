package utils

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Size unit multipliers
const (
	KB = 1024
	MB = KB * 1024
	GB = MB * 1024
	TB = GB * 1024
)

// sizePattern matches size strings like "5G", "500M", "10GB"
var sizePattern = regexp.MustCompile(`(?i)^([0-9]+(?:\.[0-9]+)?)\s*([KMGT])?B?$`)

// ConvertSizeToBytes converts a size string to bytes.
// Supported formats: "5G", "500M", "10GB", "1024K", "1T"
func ConvertSizeToBytes(sizeStr string) (int64, error) {
	sizeStr = strings.TrimSpace(sizeStr)
	
	matches := sizePattern.FindStringSubmatch(sizeStr)
	if matches == nil {
		return 0, fmt.Errorf("invalid size format: %s", sizeStr)
	}
	
	// Parse the number
	num, err := strconv.ParseFloat(matches[1], 64)
	if err != nil {
		return 0, fmt.Errorf("invalid number in size: %s", sizeStr)
	}
	
	// Apply unit multiplier
	unit := strings.ToUpper(matches[2])
	var multiplier int64 = 1
	
	switch unit {
	case "K":
		multiplier = KB
	case "M":
		multiplier = MB
	case "G":
		multiplier = GB
	case "T":
		multiplier = TB
	case "":
		multiplier = 1 // bytes
	default:
		return 0, fmt.Errorf("unknown unit: %s", unit)
	}
	
	return int64(num * float64(multiplier)), nil
}

// BytesToHuman converts bytes to a human-readable string.
func BytesToHuman(bytes int64) string {
	if bytes < KB {
		return fmt.Sprintf("%dB", bytes)
	}
	if bytes < MB {
		return fmt.Sprintf("%dKB", bytes/KB)
	}
	if bytes < GB {
		return fmt.Sprintf("%dMB", bytes/MB)
	}
	if bytes < TB {
		return fmt.Sprintf("%.1fGB", float64(bytes)/float64(GB))
	}
	return fmt.Sprintf("%.1fTB", float64(bytes)/float64(TB))
}

// BytesToHumanPrecise converts bytes to a human-readable string with more precision.
func BytesToHumanPrecise(bytes int64) string {
	if bytes < KB {
		return fmt.Sprintf("%d B", bytes)
	}
	if bytes < MB {
		return fmt.Sprintf("%.2f KB", float64(bytes)/float64(KB))
	}
	if bytes < GB {
		return fmt.Sprintf("%.2f MB", float64(bytes)/float64(MB))
	}
	if bytes < TB {
		return fmt.Sprintf("%.2f GB", float64(bytes)/float64(GB))
	}
	return fmt.Sprintf("%.2f TB", float64(bytes)/float64(TB))
}

// ParsePercentage parses a percentage string like "45%" and returns the float value.
func ParsePercentage(pctStr string) (float64, error) {
	pctStr = strings.TrimSpace(pctStr)
	pctStr = strings.TrimSuffix(pctStr, "%")
	
	pct, err := strconv.ParseFloat(pctStr, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid percentage: %s", pctStr)
	}
	
	return pct, nil
}

// FormatPercentage formats a float as a percentage string.
func FormatPercentage(pct float64) string {
	return fmt.Sprintf("%.1f%%", pct)
}


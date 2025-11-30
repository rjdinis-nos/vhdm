package utils

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

const (
	KB = 1024
	MB = KB * 1024
	GB = MB * 1024
	TB = GB * 1024
)

var sizePattern = regexp.MustCompile(`(?i)^([0-9]+(?:\.[0-9]+)?)\s*([KMGT])?B?$`)

func ConvertSizeToBytes(sizeStr string) (int64, error) {
	sizeStr = strings.TrimSpace(sizeStr)
	matches := sizePattern.FindStringSubmatch(sizeStr)
	if matches == nil {
		return 0, fmt.Errorf("invalid size format: %s", sizeStr)
	}
	num, err := strconv.ParseFloat(matches[1], 64)
	if err != nil {
		return 0, fmt.Errorf("invalid number in size: %s", sizeStr)
	}
	var multiplier int64 = 1
	switch strings.ToUpper(matches[2]) {
	case "K":
		multiplier = KB
	case "M":
		multiplier = MB
	case "G":
		multiplier = GB
	case "T":
		multiplier = TB
	}
	return int64(num * float64(multiplier)), nil
}

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

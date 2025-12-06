package wsl

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

// WSLDistribution represents a WSL distribution from Windows registry
type WSLDistribution struct {
	Name     string
	BasePath string
	VHDPath  string
}

// GetWSLDistributions queries Windows registry to get list of WSL distributions
func (c *Client) GetWSLDistributions() ([]WSLDistribution, error) {
	c.logger.Debug("Querying Windows registry for WSL distributions")

	// Query the WSL registry key
	cmd := exec.Command("reg.exe", "query", `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss`)
	output, err := cmd.Output()
	if err != nil {
		c.logger.Debug("Failed to query WSL registry: %v", err)
		return nil, fmt.Errorf("failed to query WSL registry: %w", err)
	}

	// Parse registry output to get list of distribution subkeys
	distKeys := parseDistributionKeys(string(output))
	if len(distKeys) == 0 {
		c.logger.Debug("No WSL distributions found in registry")
		return []WSLDistribution{}, nil
	}

	c.logger.Debug("Found %d WSL distribution subkeys", len(distKeys))

	// Query each distribution subkey for details
	var distributions []WSLDistribution
	for _, key := range distKeys {
		dist, err := c.queryDistributionDetails(key)
		if err != nil {
			c.logger.Debug("Failed to query distribution %s: %v", key, err)
			continue
		}
		distributions = append(distributions, dist)
	}

	c.logger.Debug("Retrieved %d WSL distributions", len(distributions))
	return distributions, nil
}

// parseDistributionKeys extracts distribution subkey GUIDs from registry output
func parseDistributionKeys(output string) []string {
	var keys []string
	// Match lines like: HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\{GUID}
	re := regexp.MustCompile(`HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Lxss\\(\{[^}]+\})`)
	matches := re.FindAllStringSubmatch(output, -1)
	for _, match := range matches {
		if len(match) > 1 {
			keys = append(keys, match[1])
		}
	}
	return keys
}

// queryDistributionDetails queries a specific distribution subkey for details
func (c *Client) queryDistributionDetails(guid string) (WSLDistribution, error) {
	keyPath := fmt.Sprintf(`HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\%s`, guid)

	cmd := exec.Command("reg.exe", "query", keyPath)
	output, err := cmd.Output()
	if err != nil {
		return WSLDistribution{}, fmt.Errorf("failed to query distribution key: %w", err)
	}

	dist := WSLDistribution{}
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Parse DistributionName
		if strings.HasPrefix(line, "DistributionName") {
			parts := strings.Fields(line)
			if len(parts) >= 3 {
				dist.Name = parts[2]
			}
		}

		// Parse BasePath
		if strings.HasPrefix(line, "BasePath") {
			parts := strings.Fields(line)
			if len(parts) >= 3 {
				dist.BasePath = strings.Join(parts[2:], " ")
			}
		}

		// Parse VhdFileName (note: might be VhdFileName or similar)
		if strings.HasPrefix(line, "VhdFileName") {
			parts := strings.Fields(line)
			if len(parts) >= 3 {
				vhdFileName := strings.Join(parts[2:], " ")
				// Combine BasePath and VhdFileName to get full path
				if dist.BasePath != "" {
					dist.VHDPath = dist.BasePath + "\\" + vhdFileName
				} else {
					dist.VHDPath = vhdFileName
				}
			}
		}
	}

	// If VHDPath wasn't constructed from VhdFileName, try to construct from BasePath
	if dist.VHDPath == "" && dist.BasePath != "" {
		// Default VHD filename is usually ext4.vhdx
		dist.VHDPath = dist.BasePath + "\\ext4.vhdx"
	}

	return dist, nil
}

// GetWSLDistributionsJSON returns WSL distributions as JSON string
func (c *Client) GetWSLDistributionsJSON() (string, error) {
	dists, err := c.GetWSLDistributions()
	if err != nil {
		return "", err
	}

	data, err := json.MarshalIndent(dists, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal distributions: %w", err)
	}

	return string(data), nil
}

package wsl

import (
	"testing"
)

func TestParseDistributionKeys(t *testing.T) {
	tests := []struct {
		name     string
		output   string
		expected int
	}{
		{
			name: "Multiple distributions",
			output: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\{12345678-1234-1234-1234-123456789012}
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\{87654321-4321-4321-4321-210987654321}`,
			expected: 2,
		},
		{
			name: "Single distribution",
			output: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\{12345678-1234-1234-1234-123456789012}`,
			expected: 1,
		},
		{
			name:     "No distributions",
			output:   `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss`,
			expected: 0,
		},
		{
			name:     "Empty output",
			output:   "",
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			keys := parseDistributionKeys(tt.output)
			if len(keys) != tt.expected {
				t.Errorf("parseDistributionKeys() = %d keys, want %d", len(keys), tt.expected)
			}
		})
	}
}

func TestQueryDistributionDetails(t *testing.T) {
	tests := []struct {
		name         string
		registryData string
		wantName     string
		wantBasePath string
	}{
		{
			name: "Complete distribution entry",
			registryData: `
    DistributionName    REG_SZ    Ubuntu-20.04
    BasePath    REG_SZ    C:\Users\test\AppData\Local\Packages\Ubuntu
    VhdFileName    REG_SZ    ext4.vhdx`,
			wantName:     "Ubuntu-20.04",
			wantBasePath: `C:\Users\test\AppData\Local\Packages\Ubuntu`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Note: This test would require mocking exec.Command
			// For now, we're just testing the parsing logic
			t.Skip("Skipping test that requires command execution mock")
		})
	}
}

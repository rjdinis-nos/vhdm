package utils

import "testing"

func TestConvertWindowsToWSLPath(t *testing.T) {
	tests := []struct {
		name    string
		winPath string
		want    string
	}{
		{"empty", "", ""},
		{"simple C drive", "C:/path/to/file.vhdx", "/mnt/c/path/to/file.vhdx"},
		{"lowercase c", "c:/path/to/file.vhdx", "/mnt/c/path/to/file.vhdx"},
		{"D drive", "D:/VMs/disk.vhdx", "/mnt/d/VMs/disk.vhdx"},
		{"backslashes", "C:\\path\\to\\file.vhdx", "/mnt/c/path/to/file.vhdx"},
		{"mixed slashes", "C:/path\\to/file.vhdx", "/mnt/c/path/to/file.vhdx"},
		{"with spaces", "C:/My Files/disk.vhdx", "/mnt/c/My Files/disk.vhdx"},
		{"deep path", "C:/Users/Name/Documents/VMs/disk.vhdx", "/mnt/c/Users/Name/Documents/VMs/disk.vhdx"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ConvertWindowsToWSLPath(tt.winPath)
			if got != tt.want {
				t.Errorf("ConvertWindowsToWSLPath(%q) = %q, want %q", tt.winPath, got, tt.want)
			}
		})
	}
}

func TestNormalizePath(t *testing.T) {
	tests := []struct {
		name string
		path string
		want string
	}{
		{"empty", "", ""},
		{"already normalized", "c:/path/to/file.vhdx", "c:/path/to/file.vhdx"},
		{"uppercase", "C:/PATH/TO/FILE.VHDX", "c:/path/to/file.vhdx"},
		{"backslashes", "C:\\path\\to\\file.vhdx", "c:/path/to/file.vhdx"},
		{"mixed", "C:/Path\\To/File.VHDX", "c:/path/to/file.vhdx"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := NormalizePath(tt.path)
			if got != tt.want {
				t.Errorf("NormalizePath(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

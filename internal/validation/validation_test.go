package validation

import "testing"

func TestValidateWindowsPath(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		wantErr bool
	}{
		// Valid paths
		{"valid basic", "C:/path/to/file.vhdx", false},
		{"valid backslash", "C:\\path\\to\\file.vhdx", false},
		{"valid mixed slashes", "C:/path\\to/file.vhdx", false},
		{"valid lowercase drive", "c:/path/to/file.vhdx", false},
		{"valid D drive", "D:/VMs/disk.vhdx", false},
		{"valid deep path", "C:/Users/Name/Documents/VMs/disk.vhdx", false},
		{"valid with spaces", "C:/My VMs/disk.vhdx", false},
		{"valid with dashes", "C:/my-vms/test-disk.vhdx", false},
		{"valid with underscores", "C:/my_vms/test_disk.vhdx", false},
		
		// Invalid paths
		{"empty", "", true},
		{"no drive letter", "/path/to/file.vhdx", true},
		{"invalid drive format", "C/path/to/file.vhdx", true},
		{"unix path", "/mnt/c/path/file.vhdx", true},
		{"relative path", "path/to/file.vhdx", true},
		{"path traversal", "C:/path/../secret/file.vhdx", true},
		{"dollar sign", "C:/path/$var/file.vhdx", true},
		{"backtick", "C:/path/`cmd`/file.vhdx", true},
		{"semicolon", "C:/path;rm -rf/file.vhdx", true},
		{"pipe", "C:/path|cat/file.vhdx", true},
		{"ampersand", "C:/path&cmd/file.vhdx", true},
		{"angle brackets", "C:/path<>/file.vhdx", true},
		{"double quotes", "C:/path\"/file.vhdx", true},
		{"single quotes", "C:/path'/file.vhdx", true},
		{"asterisk", "C:/path/*/file.vhdx", true},
		{"question mark", "C:/path/?/file.vhdx", true},
		{"square brackets", "C:/path/[test]/file.vhdx", true},
		{"exclamation", "C:/path/!/file.vhdx", true},
		{"tilde", "C:/path/~/file.vhdx", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateWindowsPath(tt.path)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateWindowsPath(%q) error = %v, wantErr %v", tt.path, err, tt.wantErr)
			}
		})
	}
}

func TestValidateUUID(t *testing.T) {
	tests := []struct {
		name    string
		uuid    string
		wantErr bool
	}{
		// Valid UUIDs
		{"valid lowercase", "761c723c-80c8-41dc-b322-6f04d1160e43", false},
		{"valid uppercase", "761C723C-80C8-41DC-B322-6F04D1160E43", false},
		{"valid mixed case", "761c723C-80c8-41DC-b322-6f04D1160e43", false},
		{"valid all zeros", "00000000-0000-0000-0000-000000000000", false},
		{"valid all f", "ffffffff-ffff-ffff-ffff-ffffffffffff", false},
		
		// Invalid UUIDs
		{"empty", "", true},
		{"too short", "761c723c-80c8-41dc-b322", true},
		{"too long", "761c723c-80c8-41dc-b322-6f04d1160e43-extra", true},
		{"no dashes", "761c723c80c841dcb3226f04d1160e43", true},
		{"wrong dash positions", "761c723c80c8-41dc-b322-6f04d1160e43", true},
		{"invalid char g", "761c723g-80c8-41dc-b322-6f04d1160e43", true},
		{"invalid char z", "761c723z-80c8-41dc-b322-6f04d1160e43", true},
		{"spaces", "761c723c 80c8 41dc b322 6f04d1160e43", true},
		{"curly braces", "{761c723c-80c8-41dc-b322-6f04d1160e43}", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateUUID(tt.uuid)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateUUID(%q) error = %v, wantErr %v", tt.uuid, err, tt.wantErr)
			}
		})
	}
}

func TestValidateMountPoint(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		wantErr bool
	}{
		// Valid mount points
		{"valid /mnt", "/mnt/data", false},
		{"valid /home", "/home/user/mount", false},
		{"valid root level", "/data", false},
		{"valid deep path", "/mnt/vhd/storage/data", false},
		{"valid with dashes", "/mnt/my-disk", false},
		{"valid with underscores", "/mnt/my_disk", false},
		{"valid with numbers", "/mnt/disk1", false},
		
		// Invalid mount points
		{"empty", "", true},
		{"relative path", "mnt/data", true},
		{"windows path", "C:/mnt/data", true},
		{"path traversal", "/mnt/../secret", true},
		{"dollar sign", "/mnt/$var", true},
		{"backtick", "/mnt/`cmd`", true},
		{"semicolon", "/mnt;rm -rf", true},
		{"pipe", "/mnt|cat", true},
		{"ampersand", "/mnt&cmd", true},
		{"double quotes", "/mnt/\"test\"", true},
		{"single quotes", "/mnt/'test'", true},
		{"asterisk", "/mnt/*", true},
		{"question mark", "/mnt/?", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateMountPoint(tt.path)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateMountPoint(%q) error = %v, wantErr %v", tt.path, err, tt.wantErr)
			}
		})
	}
}

func TestValidateDeviceName(t *testing.T) {
	tests := []struct {
		name    string
		devName string
		wantErr bool
	}{
		// Valid device names
		{"valid sda", "sda", false},
		{"valid sdb", "sdb", false},
		{"valid sdd", "sdd", false},
		{"valid sdz", "sdz", false},
		{"valid sdaa", "sdaa", false},
		{"valid sdzz", "sdzz", false},
		{"with /dev/ prefix", "/dev/sdd", false},
		
		// Invalid device names
		{"empty", "", true},
		{"just sd", "sd", true},
		{"sda1 partition", "sda1", true},
		{"nvme", "nvme0n1", true},
		{"loop", "loop0", true},
		{"uppercase", "SDA", true},
		{"hda", "hda", true},
		{"xvda", "xvda", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateDeviceName(tt.devName)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateDeviceName(%q) error = %v, wantErr %v", tt.devName, err, tt.wantErr)
			}
		})
	}
}

func TestValidateSizeString(t *testing.T) {
	tests := []struct {
		name    string
		size    string
		wantErr bool
	}{
		// Valid sizes
		{"gigabytes", "5G", false},
		{"megabytes", "500M", false},
		{"kilobytes", "1024K", false},
		{"terabytes", "1T", false},
		{"bytes", "1024B", false},
		{"lowercase g", "5g", false},
		{"with GB", "5GB", false},
		{"decimal", "1.5G", false},
		{"just number", "1024", false},
		
		// Invalid sizes
		{"empty", "", true},
		{"negative", "-5G", true},
		{"letters only", "five", true},
		{"invalid unit", "5X", true},
		{"spaces", "5 G", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateSizeString(tt.size)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateSizeString(%q) error = %v, wantErr %v", tt.size, err, tt.wantErr)
			}
		})
	}
}

func TestValidateFilesystemType(t *testing.T) {
	tests := []struct {
		name    string
		fsType  string
		wantErr bool
	}{
		// Valid filesystem types
		{"ext4", "ext4", false},
		{"ext3", "ext3", false},
		{"ext2", "ext2", false},
		{"xfs", "xfs", false},
		{"btrfs", "btrfs", false},
		
		// Invalid filesystem types
		{"empty", "", true},
		{"ntfs", "ntfs", true},
		{"fat32", "fat32", true},
		{"vfat", "vfat", true},
		{"exfat", "exfat", true},
		{"uppercase EXT4", "EXT4", true},
		{"unknown", "foobar", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateFilesystemType(tt.fsType)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateFilesystemType(%q) error = %v, wantErr %v", tt.fsType, err, tt.wantErr)
			}
		})
	}
}

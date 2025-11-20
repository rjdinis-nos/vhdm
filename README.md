# WSL VHD Disk Management Scripts

This repository contains a collection of bash scripts for managing Virtual Hard Disk (VHD/VHDX) files in Windows Subsystem for Linux (WSL). These scripts provide a convenient command-line interface for creating, mounting, unmounting, and managing VHD disks within WSL environments.

## Scripts Overview

### 1. `disk_management.sh`
The main script providing a comprehensive CLI for VHD disk operations including mount, unmount, status checking, and creation.

### 2. `libs/`
A directory containing library functions and helper scripts:
- `wsl_helpers.sh` - Reusable bash functions for VHD operations, providing the core functionality used by other scripts.

### 3. `tests/`
A directory containing test scripts for validating functionality. See [tests/README.md](tests/README.md) for details.

---

## Installation & Requirements

### Prerequisites
- **WSL 2** running on Windows
- **qemu-img** - For creating VHD files
  - Arch/Manjaro: `sudo pacman -Sy qemu-img`
  - Ubuntu/Debian: `sudo apt install qemu-utils`
  - Fedora: `sudo dnf install qemu-img`
- **jq** - For JSON parsing
  - Most distributions: `sudo <package-manager> install jq`

### Setup
```bash
# Clone or copy the scripts to your desired location
cd /home/$USER/base_config/scripts

# Make scripts executable
chmod +x disk_management.sh libs/wsl_helpers.sh

# Source the helper functions in your scripts (if needed)
source /home/$USER/base_config/scripts/libs/wsl_helpers.sh
```

---

## Usage Guide

### Main Script: `disk_management.sh`

#### Command Format
```bash
./disk_management.sh [OPTIONS] COMMAND [COMMAND_OPTIONS]
```

#### Global Options
- `-q, --quiet` - Run in quiet mode (minimal output)
- `-h, --help` - Show help message

#### Available Commands

##### 1. **mount** - Attach and mount a VHD disk

**Format:**
```bash
./disk_management.sh mount [OPTIONS]
```

**Options:**
- `--path PATH` - VHD file path (Windows format, e.g., C:/VMs/disk.vhdx)
- `--mount-point PATH` - Mount point path (Linux format)
- `--name NAME` - VHD name for WSL attachment

**Examples:**
```bash
# Mount with default settings
./disk_management.sh mount

# Mount with custom path and mount point
./disk_management.sh mount --path C:/VMs/mydisk.vhdx --mount-point /mnt/data

# Mount with all options specified
./disk_management.sh mount --path C:/aNOS/VMs/disk.vhdx --mount-point /home/user/disk --name mydisk
```

---

##### 2. **umount/unmount** - Unmount and detach a VHD disk

**Format:**
```bash
./disk_management.sh umount [OPTIONS]
```

**Options:**
- `--path PATH` - VHD file path (Windows format, UUID will be auto-discovered)
- `--uuid UUID` - VHD UUID (optional if path or mount-point provided)
- `--mount-point PATH` - Mount point path (UUID will be auto-discovered)

**Note**: Provide at least one option. UUID will be automatically discovered when possible.

**Examples:**
```bash
# Unmount by path (UUID discovered automatically)
./disk_management.sh umount --path C:/VMs/disk.vhdx

# Unmount by mount point (UUID discovered automatically)
./disk_management.sh umount --mount-point /mnt/data

# Unmount by explicit UUID
./disk_management.sh umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293
```

---

##### 3. **status** - Show VHD disk status

**Format:**
```bash
./disk_management.sh status [OPTIONS]
```

**Options:**
- `--path PATH` - Show status for specific VHD path (UUID auto-discovered)
- `--uuid UUID` - Show status for specific UUID (optional if path or mount-point provided)
- `--mount-point PATH` - Show status for specific mount point (UUID auto-discovered)
- `--all` - Show all attached VHDs

**Examples:**
```bash
# Show all attached VHDs
./disk_management.sh status --all

# Show status by path (UUID discovered automatically)
./disk_management.sh status --path C:/VMs/disk.vhdx

# Show status by mount point (UUID discovered automatically)
./disk_management.sh status --mount-point /mnt/data

# Show status for specific UUID
./disk_management.sh status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293

# Quiet mode - machine-readable output
./disk_management.sh -q status --all
```

---

##### 4. **create** - Create a new VHD disk

**Format:**
```bash
./disk_management.sh create [OPTIONS]
```

**Options:**
- `--path PATH` - VHD file path (Windows format, **required**)
- `--size SIZE` - VHD size (e.g., 1G, 500M, 10G) [default: 1G]
- `--name NAME` - VHD name for WSL attachment [default: disk]
- `--mount-point PATH` - Mount point path [default: /home/$USER/share]
- `--filesystem TYPE` - Filesystem type (ext4, ext3, xfs, etc.) [default: ext4]

**Examples:**
```bash
# Create 1GB VHD with defaults
./disk_management.sh create --path C:/VMs/newdisk.vhdx

# Create 5GB VHD with custom name
./disk_management.sh create --path C:/VMs/bigdisk.vhdx --size 5G --name mydisk

# Create VHD with all options
./disk_management.sh create --path C:/VMs/data.vhdx --size 10G --name datastore --filesystem ext4 --mount-point /mnt/datastore

# Create and immediately use (requires manual mount after creation)
./disk_management.sh create --path C:/VMs/test.vhdx --size 2G
# Note: After creation, the VHD is attached but not mounted
# To mount: sudo mkdir -p /mnt/test && sudo mount UUID=<reported-uuid> /mnt/test
```

---

## WSL Helper Functions Library

The `libs/wsl_helpers.sh` file provides reusable functions that can be sourced in other scripts.

### Key Functions

#### VHD Status Checks
- `wsl_is_vhd_attached UUID` - Check if VHD is attached to WSL
- `wsl_is_vhd_mounted UUID` - Check if VHD is mounted to filesystem
- `wsl_get_vhd_info UUID` - Get device information

#### VHD Operations
- `wsl_attach_vhd PATH [NAME]` - Attach VHD to WSL
- `wsl_detach_vhd PATH` - Detach VHD from WSL
- `wsl_mount_vhd_by_uuid UUID MOUNT_POINT` - Mount by UUID
- `wsl_unmount_vhd MOUNT_POINT` - Unmount from filesystem

#### Complete Operations
- `wsl_complete_mount PATH UUID MOUNT_POINT [NAME]` - Full mount workflow
- `wsl_complete_unmount PATH UUID MOUNT_POINT` - Full unmount workflow

#### Utility Functions
- `wsl_get_block_devices` - List all block devices
- `wsl_get_disk_uuids` - List all disk UUIDs
- `wsl_find_uuid_by_path PATH` - Find UUID of attached VHD by file path
- `wsl_find_uuid_by_mountpoint MOUNT_POINT` - Find UUID by mount point
- `wsl_find_dynamic_vhd_uuid` - Find first non-system disk UUID
- `wsl_create_vhd PATH SIZE [FS_TYPE] [NAME]` - Create and format new VHD

### Usage Example
```bash
#!/bin/bash
source /path/to/libs/wsl_helpers.sh

# Check if VHD is attached
if wsl_is_vhd_attached "57fd0f3a-4077-44b8-91ba-5abdee575293"; then
    echo "VHD is attached"
fi

# Mount VHD
wsl_mount_vhd_by_uuid "57fd0f3a-4077-44b8-91ba-5abdee575293" "/mnt/mydisk"
```

---

## Common Workflows

### First-Time Setup
```bash
# 1. Create a new VHD
./disk_management.sh create --path C:/VMs/mydisk.vhdx --size 5G --name mydisk

# 2. The UUID will be displayed. Use it to mount:
sudo mkdir -p /mnt/mydisk
sudo mount UUID=<reported-uuid> /mnt/mydisk

# 3. Verify it's mounted
./disk_management.sh status --all
```

### Daily Usage
```bash
# Mount your VHD
./disk_management.sh mount --path C:/VMs/mydisk.vhdx --mount-point /mnt/mydisk

# Work with your files...

# Unmount when done
./disk_management.sh umount --path C:/VMs/mydisk.vhdx
```

### Troubleshooting
```bash
# Check what VHDs are currently attached
./disk_management.sh status --all

# Check specific VHD status
./disk_management.sh status --path C:/VMs/mydisk.vhdx

# Force unmount if processes are blocking
sudo lsof +D /mnt/mydisk  # Find processes using mount point
sudo umount -l /mnt/mydisk  # Lazy unmount

# Then detach from WSL
./disk_management.sh umount --path C:/VMs/mydisk.vhdx
```

---

## Testing

The repository includes a comprehensive test suite for validating functionality. 

**Quick Start:**
```bash
# Run all tests
./tests/test_status.sh

# Run with verbose output
./tests/test_status.sh -v
```

For detailed information about the test suite, coverage, configuration, and adding new tests, see **[tests/README.md](tests/README.md)**.

---

## Configuration

The `disk_management.sh` script has default configuration values that can be modified at the top of the script:

```bash
WSL_DISKS_DIR="C:/aNOS/VMs/wsl_disks/"  # Default VHD directory
VHD_PATH="${WSL_DISKS_DIR}disk.vhdx"    # Default VHD path
MOUNT_POINT="/home/rjdinis/disk"        # Default mount point
VHD_NAME="disk"                          # Default VHD name
```

**UUID Discovery**: UUIDs are no longer stored as defaults. The system automatically discovers UUIDs from:
- VHD file paths (when attached)
- Mount points (when mounted)
- Explicit `--uuid` parameter when needed

---

## Output Examples

### Standard Mode
```
========================================
  VHD Disk Mount Operation
========================================

[✓] VHD attached successfully
  Detected UUID: 57fd0f3a-4077-44b8-91ba-5abdee575293
  Detected Device: /dev/sdd

  Device: /dev/sdd
  Available: 800M
  Used: 15%
  Mounted at: /mnt/mydisk

[✓] VHD mounted successfully

========================================
  Mount operation completed
========================================
```

### Quiet Mode
```
C:/VMs/mydisk.vhdx (57fd0f3a-4077-44b8-91ba-5abdee575293): attached,mounted
```

---

## Notes & Tips

1. **Path Formats**: 
   - Windows paths should use forward slashes: `C:/VMs/disk.vhdx`
   - Linux paths are standard: `/mnt/mydisk`

2. **Permissions**: Many operations require `sudo` for mounting/unmounting

3. **VHD Location**: Keep VHD files on your Windows filesystem (C: drive) for best performance

4. **UUID Persistence**: The UUID of a VHD changes each time you format it, but persists across mounts

5. **Background Processes**: Before unmounting, ensure no processes are using the mount point

6. **WSL Integration**: These scripts use `wsl.exe` commands to interact with Windows, ensuring proper integration

---

## Troubleshooting

### Error: "VHD is attached but not mounted"
This means WSL can see the VHD but it's not available in your filesystem. Run:
```bash
./disk_management.sh mount --path <your-vhd-path>
```

### Error: "Failed to unmount VHD"
Check for processes using the mount point:
```bash
sudo lsof +D /mnt/mydisk
# Kill processes or use lazy unmount
sudo umount -l /mnt/mydisk
```

### Error: "qemu-img not found"
Install qemu-img for your distribution:
```bash
# Arch/Manjaro
sudo pacman -Sy qemu-img

# Ubuntu/Debian
sudo apt install qemu-utils
```

---

## License

These scripts are provided as-is for managing VHD disks in WSL environments.

## Contributing

Feel free to modify and extend these scripts for your specific use cases.

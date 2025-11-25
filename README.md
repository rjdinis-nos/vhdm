# WSL VHD Disk Management Scripts

This repository contains a collection of bash scripts for managing Virtual Hard Disk (VHD/VHDX) files in Windows Subsystem for Linux (WSL). These scripts provide a convenient command-line interface for creating, mounting, unmounting, and managing VHD disks within WSL environments.

## Scripts Overview

### 1. `vhdm.sh`
The main script providing a comprehensive CLI for VHD disk operations including mount, unmount, status checking, and creation.

### 2. `libs/`
A directory containing library functions and helper scripts:
- `wsl_vhd_mngt.sh` - WSL-specific functions for VHD operations, providing core WSL integration functionality.
- `utils.sh` - Utility functions for size calculations, format conversions, and general helper operations.

### 4. `tests/`
A directory containing test scripts for validating functionality. See [tests/README.md](tests/README.md) for details.

---

## Key Features

### Persistent VHD Tracking

The system automatically tracks VHD path→UUID associations in a persistent JSON file, enabling seamless multi-VHD operations:

- **Location**: `~/.config/wsl-disk-management/vhd_mapping.json`
- **Automatic**: No manual configuration needed - tracking happens in the background
- **Fast**: Priority lookup from tracking file before device scanning
- **Multi-VHD support**: Works with multiple VHDs attached simultaneously
- **Mount point tracking**: Supports VHDs mounted at multiple locations
- **Device name tracking**: Tracks device names (e.g., sde, sdd) for easy reference
- **Persistent**: Survives reboots and detach/reattach cycles

**Benefits:**
- No need to remember or specify UUIDs for most operations
- Use path-based commands even with multiple VHDs attached
- Faster UUID discovery (no device scanning required)
- Automatic cleanup when VHDs are deleted
- **Automatic resource cleanup**: VHDs are automatically detached on script failure or interruption (Ctrl+C), preventing orphaned attachments

**Usage:**
Simply use path-based commands as normal - tracking works automatically:
```bash
# Path-based operations
./vhdm.sh mount --vhd-path C:/VMs/disk2.vhdx --mount-point /mnt/disk2
./vhdm.sh status --vhd-path C:/VMs/disk2.vhdx

# Attach operation
./vhdm.sh attach --vhd-path C:/VMs/disk.vhdx

# Unmount works with path
./vhdm.sh umount --vhd-path C:/VMs/disk2.vhdx
```

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
- **rsync** - For file copying with attribute preservation (used by resize command)
  - Usually pre-installed, otherwise: `sudo <package-manager> install rsync`

### Setup
```bash
# Clone and make scripts executable
chmod +x vhdm.sh libs/wsl_vhd_mngt.sh
```

---

## Usage Guide

### Main Script: `vhdm.sh`

#### Command Format
```bash
./vhdm.sh [OPTIONS] COMMAND [COMMAND_OPTIONS]
```

#### Global Options
- `-q, --quiet` - Run in quiet mode (minimal output)
- `-d, --debug` - Run in debug mode (show all commands before execution)
- `-h, --help` - Show help message

#### Available Commands

##### 1. **attach** - Attach a VHD to WSL (without mounting)

**Format:**
```bash
./vhdm.sh attach [OPTIONS]
```

**Options:**
- `--vhd-path PATH` - VHD file path (Windows format, **required**)

**Description:**
Attaches a VHD to WSL, making it available as a block device (e.g., `/dev/sdX`) without mounting it to the filesystem. This is useful when you need the VHD attached for operations but don't need filesystem access yet.

**Key Features:**
- Idempotent - safe to run multiple times (detects already-attached VHDs)
- Automatic device detection and UUID reporting (works for both formatted and unformatted VHDs)
- Device name identification and tracking
- Reliable snapshot-based detection (excludes system disks, only detects dynamically attached VHDs)
- Supports quiet and debug modes

**Examples:**
```bash
# Basic attach
./vhdm.sh attach --vhd-path C:/VMs/disk.vhdx

# Quiet mode for scripts
./vhdm.sh -q attach --vhd-path C:/VMs/disk.vhdx

# Debug mode to see commands
./vhdm.sh -d attach --vhd-path C:/VMs/disk.vhdx

# Idempotent - safe to run multiple times
./vhdm.sh attach --vhd-path C:/VMs/disk.vhdx
# Output: "VHD is already attached to WSL"
```

**After Attach:**
- VHD is accessible as a block device (e.g., `/dev/sdd`)
- Device name is always reported
- UUID is reported if VHD is formatted (unformatted VHDs will show a warning with format instructions)
- VHD is NOT mounted to filesystem yet
- Use `mount` command or manual `sudo mount UUID=<uuid> <mount-point>` to mount

---

##### 2. **mount** - Attach and mount a VHD disk

**Format:**
```bash
./vhdm.sh mount [OPTIONS]
```

**Options:**
- `--vhd-path PATH` - VHD file path (Windows format, e.g., C:/VMs/disk.vhdx)
- `--mount-point PATH` - Mount point path (Linux format, **required**)
- `--dev-name DEVICE` - Device name (e.g., sde) - alternative to --vhd-path

**Note:** Either `--vhd-path` or `--dev-name` must be provided (but not both).

**Key Features:**
- Idempotent - safe to run multiple times (detects already-mounted VHDs)
- Automatically updates tracking file with mount point (even when already mounted)
- Supports both `--vhd-path` and `--dev-name` for flexible mounting
- Creates mount point directory if it doesn't exist

**Examples:**
```bash
# Mount using VHD path
./vhdm.sh mount --vhd-path C:/VMs/mydisk.vhdx --mount-point /mnt/data

# Mount using device name (when VHD is already attached)
./vhdm.sh mount --dev-name sde --mount-point /mnt/data

# Mount with all options specified
./vhdm.sh mount --vhd-path C:/aNOS/VMs/disk.vhdx --mount-point /home/user/disk

# Idempotent - safe to run multiple times
./vhdm.sh mount --dev-name sde --mount-point /mnt/data
# Output: "VHD is already mounted at /mnt/data" (tracking file still updated)
```

---

##### 3. **umount/unmount** - Unmount a VHD disk (optionally detach)

**Format:**
```bash
./vhdm.sh umount [OPTIONS]
```

**Options:**
- `--vhd-path PATH` - VHD file path (Windows format, UUID will be auto-discovered)
- `--uuid UUID` - VHD UUID (optional if vhd-path or mount-point provided)
- `--mount-point PATH` - Mount point path (UUID will be auto-discovered)

**Note**: Provide at least one option. UUID will be automatically discovered when possible. If `--vhd-path` is provided, the VHD will also be detached after unmounting.

**Examples:**
```bash
# Unmount by path (UUID discovered automatically)
./vhdm.sh umount --vhd-path C:/VMs/disk.vhdx

# Unmount by mount point (UUID discovered automatically)
./vhdm.sh umount --mount-point /mnt/data

# Unmount by explicit UUID
./vhdm.sh umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293
```

---

##### 4. **detach** - Detach a VHD from WSL (unmounts first if mounted)

**Format:**
```bash
./vhdm.sh detach [OPTIONS]
```

**Options:**
- `--dev-name DEVICE` - VHD device name (e.g., sde) - alternative to --uuid
- `--uuid UUID` - VHD UUID - alternative to --dev-name
- `--vhd-path PATH` - VHD file path (optional, auto-discovered from tracking file if not provided)

**Note**: Either `--dev-name` or `--uuid` must be provided (mutually exclusive). If VHD is mounted, it will be unmounted first. The VHD path is automatically discovered from the tracking file using UUID or device name.

**How It Works:**
- If `--dev-name` is provided: Gets UUID from device name, then looks up path from tracking file
- If `--uuid` is provided: Gets device name from UUID, then looks up path from tracking file
- Unmounts filesystem if mounted
- Detaches VHD from WSL
- Saves detach event to history
- Keeps mapping in tracking file (unlike `delete`, which removes it)

**Examples:**
```bash
# Detach by device name
./vhdm.sh detach --dev-name sde

# Detach by UUID
./vhdm.sh detach --uuid 72a3165c-f1be-4497-a1fb-2c55054ac472

# Detach with explicit path (if not in tracking file)
./vhdm.sh detach --dev-name sde --vhd-path C:/VMs/disk.vhdx
```

---

##### 6. **status** - Show VHD disk status

**Format:**
```bash
./vhdm.sh status [OPTIONS]
```

**Options:**
- `--vhd-path PATH` - Show status for specific VHD path (UUID auto-discovered)
- `--uuid UUID` - Show status for specific UUID (optional if vhd-path or mount-point provided)
- `--mount-point PATH` - Show status for specific mount point (UUID auto-discovered)
- `--all` - Show all attached VHDs

**Examples:**
```bash
# Show all attached VHDs
./vhdm.sh status --all

# Show status by path (UUID discovered automatically)
./vhdm.sh status --vhd-path C:/VMs/disk.vhdx

# Show status by mount point (UUID discovered automatically)
./vhdm.sh status --mount-point /mnt/data

# Show status for specific UUID
./vhdm.sh status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293

# Quiet mode - machine-readable output
./vhdm.sh -q status --all
```

---

##### 7. **create** - Create a new VHD disk

**Format:**
```bash
./vhdm.sh create [OPTIONS]
```

**Options:**
- `--vhd-path PATH` - VHD file path (Windows format, **required**)
- `--size SIZE` - VHD size (e.g., 1G, 500M, 10G) [default: 1G]
- `--force` - Overwrite existing VHD (auto-unmounts if attached, prompts for confirmation)

**Note:** Creates VHD file only. Use 'attach' or 'mount' commands to attach and use the disk.

**Examples:**
```bash
# Create 1GB VHD with defaults
./vhdm.sh create --vhd-path C:/VMs/newdisk.vhdx

# Create 5GB VHD
./vhdm.sh create --vhd-path C:/VMs/bigdisk.vhdx --size 5G

# Create VHD with force flag
./vhdm.sh create --vhd-path C:/VMs/data.vhdx --size 10G --force

# Create and immediately use (requires manual mount after creation)
./vhdm.sh create --vhd-path C:/VMs/test.vhdx --size 2G
# Note: After creation, the VHD is attached but not mounted
# To mount: sudo mkdir -p /mnt/test && sudo mount UUID=<reported-uuid> /mnt/test
```

---

##### 8. **delete** - Delete a VHD disk file

**Format:**
```bash
./vhdm.sh delete [OPTIONS]
```

**Options:**
- `--vhd-path PATH` - VHD file path (Windows format, **required**)
- `--uuid UUID` - VHD UUID (optional if vhd-path provided)
- `--force` - Skip confirmation prompt

**Note**: VHD must be unmounted and detached before deletion.

**Examples:**
```bash
# Delete with confirmation prompt
./vhdm.sh delete --vhd-path C:/VMs/oldisk.vhdx

# Delete without confirmation (force)
./vhdm.sh delete --vhd-path C:/VMs/testdisk.vhdx --force

# Unmount and then delete
./vhdm.sh umount --vhd-path C:/VMs/disk.vhdx
./vhdm.sh delete --vhd-path C:/VMs/disk.vhdx --force
```

---

##### 9. **format** - Format a VHD disk with a filesystem

**Format:**
```bash
./vhdm.sh format [OPTIONS]
```

**Options:**
- `--dev-name NAME` - VHD device block name (e.g., sdd, sde)
- `--uuid UUID` - VHD UUID
- `--type TYPE` - Filesystem type (ext4, ext3, xfs, etc.) [default: ext4]

**Note:** Either `--dev-name` or `--uuid` must be provided. VHD must be attached before formatting. Use 'attach' command first.

**Examples:**
```bash
# Format by device name
./vhdm.sh format --dev-name sdd --type ext4

# Format by UUID
./vhdm.sh format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4

# Format with default filesystem (ext4)
./vhdm.sh format --dev-name sde
```

---

##### 10. **resize** - Resize a VHD disk

**Format:**
```bash
./vhdm.sh resize --mount-point <PATH> --size <SIZE>
```

**Options:**
- `--mount-point PATH` - Target disk mount point (**required**)
- `--size SIZE` - New disk size (e.g., 5G, 10G) (**required**)

**How It Works:**
The resize operation creates a new VHD, migrates all data, and replaces the original disk with a backup. See [RESIZE_COMMAND.md](RESIZE_COMMAND.md) for detailed documentation.

**Key Features:**
- Automatic size calculation (uses data size + 30% if requested size is too small)
- File count and size verification
- Original disk backed up as `<name>_bkp.vhdx`
- Safe operation with automatic cleanup on failure
- Supports debug mode to see all commands

**Examples:**
```bash
# Resize disk to 10GB
./vhdm.sh resize --mount-point /home/user/disk --size 10G

# Resize with automatic size calculation
# (If current data is 7GB, actual size will be ~9.1GB minimum)
./vhdm.sh resize --mount-point /mnt/data --size 5G

# Quiet mode
./vhdm.sh -q resize --mount-point /mnt/data --size 10G

# Debug mode to see all commands
./vhdm.sh -d resize --mount-point /home/user/disk --size 10G
```

**Important Notes:**
- Disk must be mounted before resizing
- Ensure sufficient Windows filesystem space (needs space for both old and new VHD during operation)
- Original VHD is backed up, not deleted - verify and manually delete backup when satisfied
- Operation may take time depending on data size (e.g., 10GB might take 5-10 minutes)

For complete documentation including size calculations, safety features, and troubleshooting, see **[RESIZE_COMMAND.md](RESIZE_COMMAND.md)**.

---

## WSL Helper Functions Library

The library files in `libs/` provide reusable functions that can be sourced in other scripts.

### `libs/wsl_vhd_mngt.sh` - WSL-Specific Functions

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

#### Tracking File Management Functions
All tracking file operations follow the standardized naming pattern `tracking_file_<action>_<what>()`:

- `tracking_file_init()` - Initialize tracking file structure
- `tracking_file_save_mapping()` - Save/update path→UUID mapping
- `tracking_file_lookup_uuid_by_path()` - Lookup UUID by VHD path
- `tracking_file_lookup_uuid_by_dev_name()` - Lookup UUID by device name
- `tracking_file_update_mount_point()` - Update mount point in tracking file
- `tracking_file_remove_mount_point()` - Remove mount point from tracking file
- `tracking_file_remove_mapping()` - Remove VHD mapping completely
- `tracking_file_save_detach_history()` - Save detach event to history
- `tracking_file_get_detach_history()` - Get detach history entries
- `tracking_file_get_last_detach_for_path()` - Get last detach event for a path

**Note**: These functions are used internally by the disk management commands. The standardized naming convention ensures consistency and maintainability across the codebase.

### `libs/utils.sh` - Utility Functions

#### Input Validation Functions
- `validate_windows_path(path)` - Validates Windows path format and rejects dangerous patterns
- `validate_uuid(uuid)` - Validates UUID format (RFC 4122)
- `validate_mount_point(mount_point)` - Validates mount point paths
- `validate_device_name(device)` - Validates device names (e.g., sdd, sde)
- `validate_size_string(size)` - Validates size strings (e.g., "5G", "500M")
- `validate_filesystem_type(fs_type)` - Whitelist validation for filesystem types
- `sanitize_string(input)` - Additional sanitization layer (defense in depth)

All validation functions return 0 on success, 1 on failure. See [Security](#security) section for detailed validation rules.

#### Logging Functions
- `log_debug(message)` - Debug messages (only shown when `DEBUG=true`)
- `log_info(message)` - Informational messages (shown unless `QUIET=true`)
- `log_warn(message)` - Warning messages (shown unless `QUIET=true`)
- `log_error(message)` - Error messages (always shown, even in quiet mode)
- `log_success(message)` - Success messages (shown unless `QUIET=true`)

All logging functions support timestamps and structured output. See [Structured Logging](#structured-logging) section for details.

#### Size and Conversion Functions
- `get_directory_size_bytes DIR` - Calculate total size of files in directory (in bytes)
  - Returns: Size in bytes or 0 on error
  - Uses `du -sb` for accurate byte-level measurements
  - Respects `DEBUG` flag for command visibility

- `convert_size_to_bytes SIZE_STRING` - Convert size string to bytes
  - Args: Size string (e.g., "5G", "500M", "10G")
  - Returns: Size in bytes
  - Supports: K/KB, M/MB, G/GB, T/TB units (case-insensitive)
  - Handles numeric-only input (assumes bytes)

- `bytes_to_human BYTES` - Convert bytes to human-readable format
  - Args: Size in bytes
  - Returns: Formatted string (e.g., "5GB", "150MB")
  - Uses bash arithmetic for size conversion

### Usage Example
```bash
#!/bin/bash
source /path/to/libs/wsl_vhd_mngt.sh
source /path/to/libs/utils.sh

# WSL-specific operations
if wsl_is_vhd_attached "57fd0f3a-4077-44b8-91ba-5abdee575293"; then
    echo "VHD is attached"
fi

# Mount VHD
wsl_mount_vhd_by_uuid "57fd0f3a-4077-44b8-91ba-5abdee575293" "/mnt/mydisk"

# Utility functions for size operations
dir_size=$(get_directory_size_bytes "/mnt/mydisk")
echo "Directory size: $(bytes_to_human $dir_size)"

# Convert size string to bytes
target_bytes=$(convert_size_to_bytes "10G")
echo "Target size: $target_bytes bytes"
```

---

## Common Workflows

### First-Time Setup
```bash
# 1. Create a new VHD
./vhdm.sh create --vhd-path C:/VMs/mydisk.vhdx --size 5G

# 2. The UUID will be displayed. Use it to mount:
sudo mkdir -p /mnt/mydisk
sudo mount UUID=<reported-uuid> /mnt/mydisk

# 3. Verify it's mounted
./vhdm.sh status --all
```

### Using Attach Command
```bash
# Attach VHD without mounting (makes it available as block device)
./vhdm.sh attach --vhd-path C:/VMs/mydisk.vhdx

# Check status to see UUID and device name
./vhdm.sh status --vhd-path C:/VMs/mydisk.vhdx

# Later, mount it manually or with mount command
sudo mount UUID=<uuid> /mnt/mydisk

# Or use mount command for full attach+mount workflow
./vhdm.sh mount --vhd-path C:/VMs/mydisk.vhdx --mount-point /mnt/mydisk
```

### Daily Usage
```bash
# Mount your VHD
./vhdm.sh mount --vhd-path C:/VMs/mydisk.vhdx --mount-point /mnt/mydisk

# Work with your files...

# Unmount when done
./vhdm.sh umount --vhd-path C:/VMs/mydisk.vhdx
```

### Troubleshooting
```bash
# Check what VHDs are currently attached
./vhdm.sh status --all

# Check specific VHD status
./vhdm.sh status --vhd-path C:/VMs/mydisk.vhdx

# Attach VHD separately from mounting (useful for debugging)
./vhdm.sh attach --vhd-path C:/VMs/mydisk.vhdx
./vhdm.sh status --uuid <uuid>  # Verify attachment

# Enable debug mode to see all commands being executed
./vhdm.sh -d status --all

# Force unmount if processes are blocking
sudo lsof +D /mnt/mydisk  # Find processes using mount point
sudo umount -l /mnt/mydisk  # Lazy unmount

# Then detach from WSL
./vhdm.sh umount --vhd-path C:/VMs/mydisk.vhdx
```

### Structured Logging

The scripts use a structured logging system with timestamps and log levels for consistent, traceable output.

**Log Levels:**
- **DEBUG** - Detailed diagnostic information (only shown when `DEBUG=true`)
- **INFO** - General information and progress updates (shown unless `QUIET=true`)
- **WARN** - Warning messages (shown unless `QUIET=true`)
- **ERROR** - Error messages (always shown, even in quiet mode)
- **SUCCESS** - Success messages (shown unless `QUIET=true`)

**Log Format:**
All log messages include timestamps:
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] message
```

**Examples:**
```bash
# Normal operation with structured logging
./vhdm.sh mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
# Output:
# [2025-01-15 14:30:45] [INFO] Attaching VHD: C:/VMs/disk.vhdx
# [2025-01-15 14:30:49] [SUCCESS] VHD attached (UUID: 550e8400-...)
# [2025-01-15 14:30:50] [INFO] Mounting disk at /mnt/data...
# [2025-01-15 14:30:51] [SUCCESS] Disk successfully mounted at /mnt/data

# Debug mode shows detailed command execution
./vhdm.sh -d mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
# Output includes:
# [2025-01-15 14:30:45] [DEBUG] Executing: wsl.exe --mount --vhd C:/VMs/disk.vhdx --bare
# [2025-01-15 14:30:46] [DEBUG] lsblk -f -J | jq -r --arg UUID '...' '.blockdevices[] | select(.uuid == $UUID) | .name'

# Quiet mode suppresses info/warn/success (errors still shown)
./vhdm.sh -q mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
# Only errors displayed (if any)

# Optional log file support
export LOG_FILE="/var/log/wsl-disk-management.log"
./vhdm.sh mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
# Messages appear on screen AND in log file
```

**Log File Support:**
Set the `LOG_FILE` environment variable to write logs to a file:
```bash
export LOG_FILE="/var/log/wsl-disk-management.log"
./vhdm.sh mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
```

Log files include all messages (except debug when `DEBUG=false`) with timestamps for audit trails and troubleshooting.

---

## Testing

The repository includes a comprehensive test suite for validating functionality. Tests produce clean output with only test results displayed, and automatically generate detailed test reports.

**Quick Start:**
```bash
# Run all tests at once
./tests/test_all.sh

# Run all tests with verbose output
./tests/test_all.sh -v

# Stop on first failure (useful for CI/CD)
./tests/test_all.sh --stop-on-failure

# Run individual test suites
./tests/test_status.sh
./tests/test_attach.sh
./tests/test_create.sh
./tests/test_delete.sh
./tests/test_mount.sh
./tests/test_umount.sh

# Run with verbose output (shows commands and details)
./tests/test_status.sh -v

# Run specific tests
./tests/test_create.sh -t 1 -t 5
```

**Test Output:** All non-test messages are suppressed, showing only:
- Test names and results (PASSED/FAILED)
- Summary statistics
- Detailed output in verbose mode

**Test Reporting:**
- **Automatic Reports**: Test results are automatically recorded after each test run
- **JSON Format**: `tests/test_report.json` stores structured test data (machine-readable)
- **Markdown Format**: `tests/test_report.md` provides human-readable reports with:
  - Summary table showing all test suites with status, counts, and duration
  - Detailed test result tables showing individual test names and status
  - Color-coded status indicators (green for passed, red for failed)
  - Navigation links between summary and detailed sections
- **Individual Test Tracking**: Each test is tracked with its number, descriptive name, and status
- **Historical Data**: Complete test execution history maintained over time

**View Test Reports:**
```bash
# View human-readable markdown report
cat tests/test_report.md

# View machine-readable JSON data
cat tests/test_report.json | jq

# View specific suite results
cat tests/test_report.json | jq '.suites["test_status.sh"]'
```

For detailed information about the test suite, coverage, configuration, adding new tests, and the reporting system, see **[tests/README.md](tests/README.md)**.

---

## Configuration

The `vhdm.sh` script has default configuration values that can be modified at the top of the script:

```bash
WSL_DISKS_DIR="C:/aNOS/VMs/wsl_disks/"  # Default VHD directory
VHD_PATH="${WSL_DISKS_DIR}disk.vhdx"    # Default VHD path
MOUNT_POINT="/home/rjdinis/disk"        # Default mount point
VHD_NAME="disk"                          # Default VHD name
```

### Persistent VHD Tracking

VHD path→UUID associations are automatically tracked in:
- **Location**: `~/.config/wsl-disk-management/vhd_mapping.json`
- **Created automatically** on first use
- **No manual configuration needed**

The tracking file maintains mappings across sessions, enabling:
- Fast UUID lookup without device scanning
- Multi-VHD support (no confusion between multiple attached VHDs)
- Mount point tracking (VHDs can have multiple mount points)

**UUID Discovery Priority:**
1. **Tracking file** - Fastest, checked first
2. **Mount point** - For mounted filesystems
3. **Snapshot-based device detection** - During attach/create operations (device-first, then UUID from device)
4. **Explicit parameter** - User-provided `--uuid`

The system automatically saves mappings when VHDs are attached/created and updates them when mounted/unmounted. The mount command updates the tracking file even when the VHD is already mounted, ensuring the tracking file stays in sync with the actual mount state.

**Internal Implementation:**
All tracking file operations use standardized function names following the pattern `tracking_file_<action>_<what>()` for consistency and maintainability. These functions handle all persistent state management automatically in the background.

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

## Security

The scripts implement comprehensive input validation to prevent command injection and path traversal vulnerabilities.

### Input Validation

All user-provided inputs are validated before use:

- **Windows Paths**: Must start with drive letter (A-Z) followed by colon and slash. Rejects command injection characters (`;`, `|`, `&`, `$`, `` ` ``, `()`, etc.), directory traversal (`..`), control characters, and paths longer than 4096 characters.

- **UUIDs**: Must match RFC 4122 format (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) with exactly 36 characters. Only hexadecimal characters allowed.

- **Mount Points**: Must be absolute paths starting with `/`. Rejects command injection characters, directory traversal, control characters, and paths longer than 4096 characters.

- **Device Names**: Must match pattern `sd[a-z]+` (e.g., `sda`, `sdd`, `sde`, `sdaa`). Maximum length: 10 characters.

- **VHD Names**: Alphanumeric with underscores and hyphens only. Maximum length: 64 characters. Cannot start/end with special characters.

- **Size Strings**: Must match pattern `number[K|M|G|T][B]?` (e.g., `5G`, `500M`, `10GB`). Maximum length: 20 characters.

- **Filesystem Types**: Whitelist validation. Allowed types: `ext2`, `ext3`, `ext4`, `xfs`, `btrfs`, `ntfs`, `vfat`, `exfat`. All other types rejected.

### Validation Functions

The validation functions are located in `libs/utils.sh`:

- `validate_windows_path()` - Validates Windows path format
- `validate_uuid()` - Validates UUID format (RFC 4122)
- `validate_mount_point()` - Validates mount point paths
- `validate_device_name()` - Validates device names
- `validate_size_string()` - Validates size strings
- `validate_filesystem_type()` - Whitelist validation for filesystem types
- `sanitize_string()` - Additional sanitization layer (defense in depth)

### Utility Functions

Additional utility functions in `libs/utils.sh`:

- `wsl_convert_path()` - Converts Windows paths to WSL paths (e.g., `C:/VMs/disk.vhdx` → `/mnt/c/VMs/disk.vhdx`)
- `convert_size_to_bytes()` - Converts size strings to bytes (e.g., `5G` → `5368709120`)
- `bytes_to_human()` - Converts bytes to human-readable format (e.g., `5368709120` → `5GB`)
- `get_directory_size_bytes()` - Calculates total size of files in directory

### Defense in Depth

The scripts implement multiple layers of security:

1. **Input Validation**: All user inputs are validated at command argument parsing
2. **Helper Function Validation**: Additional validation in helper functions that receive user input
3. **Safe Command Execution**: All user inputs validated before use in commands
4. **No Direct Command Substitution**: User input is never directly substituted into command strings without validation

### Error Messages

When validation fails, the scripts provide clear error messages with format examples, without leaking information about internal structure.

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
./vhdm.sh mount --vhd-path <your-vhd-path>
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

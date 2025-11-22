# Structured Logging Implementation

## Overview

Implemented comprehensive structured logging system to replace ad-hoc echo statements throughout the codebase. This provides consistent, timestamped logging with proper log levels.

## Logging Functions Added (`libs/utils.sh`)

### Core Logging Functions

1. **`log_debug(message)`** - Debug messages (only shown when `DEBUG=true`)
   - Color: Blue
   - Output: stderr
   - Use: Detailed diagnostic information, command execution details

2. **`log_info(message)`** - Informational messages (shown unless `QUIET=true`)
   - Color: Default
   - Output: stderr
   - Use: General information, progress updates

3. **`log_warn(message)`** - Warning messages (shown unless `QUIET=true`)
   - Color: Yellow
   - Output: stderr
   - Use: Warnings, non-critical issues

4. **`log_error(message)`** - Error messages (always shown, even in quiet mode)
   - Color: Red
   - Output: stderr
   - Use: Errors, failures, critical issues

5. **`log_success(message)`** - Success messages (shown unless `QUIET=true`)
   - Color: Green
   - Output: stderr
   - Use: Successful operations, completion messages

### Log Format

All log messages follow this format:
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] message
```

Example:
```
[2025-01-15 14:30:45] [INFO] Attaching VHD: C:/VMs/disk.vhdx
[2025-01-15 14:30:47] [DEBUG] Executing: wsl.exe --mount --vhd C:/VMs/disk.vhdx --bare --name disk
[2025-01-15 14:30:49] [SUCCESS] VHD attached (UUID: 550e8400-e29b-41d4-a716-446655440000)
```

## Features

### 1. **Respects Existing Flags**
- `DEBUG=true` - Shows debug messages
- `QUIET=true` - Suppresses info/warn/success messages (errors still shown)
- Works with existing `-d` and `-q` command-line flags

### 2. **Optional Log File Support**
Set `LOG_FILE` environment variable to write logs to file:
```bash
export LOG_FILE="/var/log/wsl-disk-management.log"
./disk_management.sh mount --path C:/VMs/disk.vhdx --mount-point /mnt/data
```

Log file includes all messages (except debug when `DEBUG=false`).

### 3. **Color-Coded Output**
- **DEBUG**: Blue
- **INFO**: Default (no color)
- **WARN**: Yellow
- **ERROR**: Red
- **SUCCESS**: Green

Colors are automatically disabled when output is redirected or in quiet mode.

## Changes Made

### Files Updated

1. **`libs/utils.sh`**
   - Added logging functions
   - Added color constants (if not already defined)
   - Added timestamp generation
   - Added log file support

2. **`libs/wsl_helpers.sh`**
   - Replaced all `echo` debug statements with `log_debug()`
   - Replaced error messages with `log_error()`
   - Replaced warnings with `log_warn()`
   - Updated `debug_cmd()` to use `log_debug()`

3. **`mount_disk.sh`**
   - Replaced error messages with `log_error()`
   - Replaced info messages with `log_info()`
   - Replaced success messages with `log_success()`
   - Fixed function name: `wsl_get_mountpoint_by_uuid` → `wsl_get_vhd_mount_point`

### Conversion Examples

**Before:**
```bash
[[ "$DEBUG" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} Created tracking directory: $dir" >&2
echo "Error: UUID is required" >&2
echo "Warning: Failed to create tracking directory: $dir" >&2
```

**After:**
```bash
log_debug "Created tracking directory: $dir"
log_error "UUID is required"
log_warn "Failed to create tracking directory: $dir"
```

## Usage Examples

### Normal Operation
```bash
./disk_management.sh mount --path C:/VMs/disk.vhdx --mount-point /mnt/data
# Output:
# [2025-01-15 14:30:45] [INFO] Attaching VHD: C:/VMs/disk.vhdx
# [2025-01-15 14:30:49] [SUCCESS] VHD attached (UUID: 550e8400-...)
# [2025-01-15 14:30:50] [INFO] Mounting disk at /mnt/data...
# [2025-01-15 14:30:51] [SUCCESS] Disk successfully mounted at /mnt/data
```

### Debug Mode
```bash
./disk_management.sh -d mount --path C:/VMs/disk.vhdx --mount-point /mnt/data
# Output includes debug messages:
# [2025-01-15 14:30:45] [DEBUG] Executing: wsl.exe --mount --vhd C:/VMs/disk.vhdx --bare --name disk
# [2025-01-15 14:30:46] [DEBUG] lsblk -f -J | jq -r --arg UUID '...' '.blockdevices[] | select(.uuid == $UUID) | .name'
```

### Quiet Mode
```bash
./disk_management.sh -q mount --path C:/VMs/disk.vhdx --mount-point /mnt/data
# Only errors shown (if any)
```

### With Log File
```bash
export LOG_FILE="/tmp/wsl-disk.log"
./disk_management.sh mount --path C:/VMs/disk.vhdx --mount-point /mnt/data
# Messages appear on screen AND in log file
```

## Benefits

1. **Consistency**: All log messages follow the same format
2. **Timestamps**: Every message includes timestamp for debugging
3. **Log Levels**: Clear distinction between debug, info, warn, error
4. **Maintainability**: Centralized logging logic, easy to modify
5. **Debugging**: Structured format makes log analysis easier
6. **Production Ready**: Optional log file support for production environments

## Backward Compatibility

- All existing functionality preserved
- `-d` and `-q` flags work as before
- Output format is enhanced but compatible
- No breaking changes to command-line interface

## Future Enhancements

Potential improvements:
- Log rotation support
- JSON log format option
- Log level filtering (e.g., only show errors)
- Structured logging for machine parsing
- Integration with system logging (syslog/journald)


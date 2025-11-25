# Copilot Instructions - WSL VHD Disk Management

## Project Overview

Bash scripts for managing VHD/VHDX files in Windows Subsystem for Linux (WSL2). Multi-script architecture:
- `vhdm.sh` - Comprehensive CLI for VHD operations (attach, mount, umount, detach, status, create, delete, resize)
- `libs/wsl_vhd_mngt.sh` - Shared WSL-specific function library
- `libs/wsl_vhd_tracking.sh` - Persistent tracking file management functions
- `libs/utils.sh` - Shared utility functions for size calculations, conversions, and input validation

The `vhdm.sh` script sources `libs/wsl_vhd_mngt.sh` (which sources `libs/wsl_vhd_tracking.sh`) and `libs/utils.sh` for core functionality.

**📖 For comprehensive architecture details, function flows, and responsibility matrix, see [copilot-code-architecture.md](copilot-code-architecture.md)**

## Architecture & Core Patterns

### Persistent Disk Tracking
The system maintains a persistent mapping file to track VHD path→UUID associations across sessions:
- **Location**: `~/.config/wsl-disk-management/vhd_mapping.json`
- **Format**: JSON with version and mappings object
- **Normalization**: Windows paths normalized to lowercase with forward slashes for case-insensitive matching
- **Usage**: Automatically saves mappings on attach/create, updates mount points on mount/unmount, removes on delete
- **Priority**: Tracking file checked first before falling back to device discovery
- **Safety**: Validates tracked UUIDs are still attached (handles stale entries gracefully)

Tracking file structure:
```json
{
  "version": "1.0",
  "mappings": {
    "c:/vms/disk1.vhdx": {
      "uuid": "uuid-1234",
      "last_attached": "2025-11-21T10:30:00Z",
      "mount_points": "/mnt/disk1"
    }
  }
}
```

**Key Functions:**
- `init_disk_tracking_file()` - Creates directory and initial JSON structure
- `normalize_vhd_path()` - Normalizes Windows paths for consistent tracking
- `save_vhd_mapping()` - Saves/updates path→UUID→mount_points association
- `lookup_vhd_uuid()` - Retrieves UUID from tracking file by path
- `update_vhd_mount_points()` - Updates mount point list for existing mapping
- `update_tracking_file_mount_point()` - Helper function that updates tracking file with mount point (handles both --vhd-path and --dev-name cases, including lookup of path from UUID when needed)
- `remove_vhd_mapping()` - Removes mapping when VHD is deleted

**Integration Points:**
- `attach_vhd()` - Saves mapping after successful attach
- `mount_vhd()` - Updates mount points after mount (or when already mounted, ensuring tracking file stays in sync)
- `umount_vhd()` - Clears mount points after unmount
- `detach_vhd()` - Clears mount points when detaching
- `delete_vhd()` - Removes mapping when VHD file is deleted
- `wsl_create_vhd()` - Saves mapping after VHD creation and formatting
- `wsl_find_uuid_by_path()` - Checks tracking file first, then falls back to device discovery

**Note:** The `mount_vhd()` command uses `update_tracking_file_mount_point()` helper function to update the tracking file. This ensures the tracking file is updated even when the VHD is already mounted at the target mount point, keeping the tracking file in sync with the actual mount state.

**Test VHD Detection:**
The `is_test_vhd()` function determines whether a VHD should skip tracking file updates. It only skips tracking when:
- `WSL_DISKS_DIR` environment variable is set (from `.env.test` during test execution)
- The VHD path is within the `WSL_DISKS_DIR` directory

This ensures that legitimate VHDs with "test" or "wsl_tests" in their paths are still tracked properly. The function no longer uses filename patterns to avoid false positives.

### Snapshot-Based Device Detection
When attaching VHDs, the scripts use device-first detection to identify newly attached disks:
```bash
# Before attach - capture block devices snapshot
local old_devs=($(wsl_get_block_devices))

# Perform attach operation
wsl_attach_vhd "$path"

# Detect new device using snapshot-based comparison
# Pass array elements directly for reliability
local new_device=$(detect_new_device_after_attach "" "${old_devs[@]}")

# Get UUID from device if available (VHD is formatted)
local uuid=$(wsl_get_uuid_by_device "$new_device")
```

**Key Points**:
- **Device-first detection**: Works for both formatted and unformatted VHDs
- **Pre-filtering**: Old devices are filtered to only include dynamically attached VHDs (sd[d-z] pattern) BEFORE sleep
- **System disk exclusion**: System disks (sda/sdb/sdc) are excluded from comparison
- **Reliable array passing**: Array elements are passed directly as arguments, not via indirect reference

This pattern is critical in `attach_vhd()`, `mount_vhd()`, `resize_vhd()`, and `wsl_create_vhd()`. System disks (sda/sdb/sdc) are WSL system volumes; dynamically attached VHDs typically appear as sd[d-z].

### Path Format Handling
- **User input**: Windows format with forward slashes: `C:/VMs/disk.vhdx`
- **Internal WSL operations**: Convert to `/mnt/c/VMs/disk.vhdx` using `wsl_convert_path()` function from `libs/utils.sh`
  - **Always use `wsl_convert_path()` instead of inline sed commands** for consistency
  - Example: `local vhd_path_wsl=$(wsl_convert_path "$path")`
- **WSL.exe calls**: Use original Windows format
- **Mount operations**: Standard Linux paths `/mnt/...` or `/home/...`

### Dual Output Modes
Functions must support both verbose and quiet modes using `QUIET` flag:
```bash
[[ "$QUIET" == "false" ]] && echo "User-friendly message"
[[ "$QUIET" == "true" ]] && echo "machine-readable: status"
```
Quiet mode outputs parseable status strings like `path (uuid): attached,mounted`.

### Input Validation & Security
All user-provided inputs are validated to prevent command injection and path traversal vulnerabilities.

**Validation Functions** (in `libs/utils.sh`):
- `validate_windows_path(path)` - Validates Windows path format, rejects command injection characters, directory traversal, control characters
- `validate_uuid(uuid)` - Validates UUID format (RFC 4122), exactly 36 hexadecimal characters
- `validate_mount_point(mount_point)` - Validates mount point paths (absolute paths starting with `/`)
- `validate_device_name(device)` - Validates device names (pattern: `sd[a-z]+`)
- `validate_size_string(size)` - Validates size strings (pattern: `number[K|M|G|T][B]?`)
- `validate_filesystem_type(fs_type)` - Whitelist validation (ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat)
- `sanitize_string(input)` - Additional sanitization layer (removes control characters)

**Validation Rules:**
- Windows paths: Must start with drive letter, reject `;`, `|`, `&`, `$`, `` ` ``, `()`, `..`, control characters, max 4096 chars
- UUIDs: RFC 4122 format, exactly 36 characters, hexadecimal only
- Mount points: Absolute paths starting with `/`, reject command injection chars, `..`, control characters, max 4096 chars
- Device names: Pattern `sd[a-z]+`, max 10 characters
- Device names: Alphanumeric only, typically 3-4 characters (e.g., sde, sdd)
- Size strings: Pattern `number[K|M|G|T][B]?`, max 20 characters
- Filesystem types: Whitelist only (ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat)

**Validation Points:**
- All command argument parsing in `vhdm.sh` (status, mount, umount, detach, delete, create, resize, format, attach, history)
- Helper functions in `libs/wsl_vhd_mngt.sh` that receive user input (`save_vhd_mapping()`, `lookup_vhd_uuid()`, `wsl_attach_vhd()`, `mount_filesystem()`, `format_vhd()`, etc.)

**Defense in Depth:**
1. Validation at command argument parsing
2. Validation in helper functions
3. Validation before command execution
4. Safe command execution (jq uses `--arg` for safe parameter passing)

**Error Messages:**
Clear error messages when validation fails, with format examples, without information leakage.

### Structured Logging
Scripts use a comprehensive structured logging system with timestamps and log levels:

**Logging Functions** (in `libs/utils.sh`):
- `log_debug(message)` - Debug messages (only when `DEBUG=true`)
- `log_info(message)` - Informational messages (unless `QUIET=true`)
- `log_warn(message)` - Warning messages (unless `QUIET=true`)
- `log_error(message)` - Error messages (always shown, even in quiet mode)
- `log_success(message)` - Success messages (unless `QUIET=true`)

**Log Format:**
All messages include timestamps: `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`

**Features:**
- Timestamps on all log entries
- Color-coded output (blue=debug, yellow=warn, red=error, green=success)
- Respects `QUIET` and `DEBUG` flags
- Optional log file support via `LOG_FILE` environment variable
- All messages go to stderr (except log file writes)

**Usage:**
```bash
# Replace echo statements with logging functions
log_info "Attaching VHD: $vhd_path"
log_debug "Executing: wsl.exe --mount --vhd $vhd_path"
log_error "Failed to mount filesystem"
log_success "VHD mounted successfully"
log_warn "VHD may still be detaching"
```

**Debug Mode Integration:**
The `debug_cmd()` wrapper now uses `log_debug()` for consistent output:
```bash
# Debug command wrapper (uses log_debug internally)
debug_cmd sudo mount UUID="$uuid" "$mount_point"

# Manual debug output for pipelines
log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
```

**Log File Support:**
Set `LOG_FILE` environment variable to write logs to file:
```bash
export LOG_FILE="/var/log/wsl-disk-management.log"
# All non-debug messages (or all messages if DEBUG=true) written to file
```

### State-Check-Then-Operate Pattern
Always check state before operations to handle idempotent behavior:
```bash
if ! wsl_is_vhd_attached "$uuid"; then
    wsl_attach_vhd "$path"
fi
if ! wsl_is_vhd_mounted "$uuid"; then
    wsl_mount_vhd "$uuid" "$mount_point"
fi
```

### Critical Rule: No Heuristic Disk Discovery

**NEVER use non-deterministic heuristics to identify which VHD/disk to operate on.**

WSL does not provide a direct path→UUID mapping after attachment. Avoid using guessing patterns like:
- ❌ "Find the first non-system disk (sd[d-z])" - arbitrary with multiple VHDs
- ❌ "Assume the most recent disk is the target" - breaks with multiple disks
- ❌ "Pick any disk that matches a pattern" - random selection

**Safe UUID Discovery Methods:**
1. ✅ **Snapshot-based detection during attach/create** - Compare before/after immediately after operation
2. ✅ **UUID from mount point** - `findmnt` or `lsblk` lookup of mounted filesystem
3. ✅ **Explicit user-provided UUID** - User specifies `--uuid` parameter

**When UUID is unknown:**
1. Count attached dynamic VHDs using `wsl_count_dynamic_vhds()`
2. If count > 1: Require explicit `--uuid` or fail with clear error
3. If count == 1: Only then use `wsl_find_dynamic_vhd_uuid()` safely
4. If count == 0: Report "no VHDs attached"

See [copilot-code-architecture.md](copilot-code-architecture.md) for detailed implementation requirements.

### Secure Temporary File Handling

All temporary file operations must use secure patterns to prevent race conditions and information disclosure:

**Requirements:**
1. ✅ Use `mktemp` with `XXXXXX` pattern for secure random file names (never use `$$` PID-based names)
2. ✅ Set trap handlers (`EXIT INT TERM`) to ensure cleanup on script interruption
3. ✅ Remove trap handlers after successful operations
4. ✅ Explicit cleanup in all error paths
5. ✅ Use `mv` for atomic file updates (not `cp` + `rm`)

**Pattern:**
```bash
# Create secure temporary file
local temp_file
temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
if [[ $? -ne 0 || -z "$temp_file" ]]; then
    log_debug "Failed to create temporary file"
    return 1
fi

# Set up trap handler for cleanup
trap "rm -f '$temp_file'" EXIT INT TERM

# Perform operation
if jq ... "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
    mv "$temp_file" "$DISK_TRACKING_FILE"  # Atomic move
    trap - EXIT INT TERM  # Remove trap on success
    return 0
else
    rm -f "$temp_file"
    trap - EXIT INT TERM  # Remove trap on error
    return 1
fi
```

**Functions Using This Pattern:**
- `save_vhd_mapping()` - Updates tracking file
- `update_vhd_mount_points()` - Updates mount points
- `remove_vhd_mapping()` - Removes VHD mappings
- `save_detach_history()` - Adds detach events

### Resource Cleanup System

All operations that attach VHDs or create temporary resources must register them for automatic cleanup on script failure or interruption:

**Requirements:**
1. ✅ Initialize cleanup system at script startup with `init_resource_cleanup()`
2. ✅ Register VHDs immediately after attachment (before operations that might fail)
3. ✅ Update registration with UUID when detected (for better cleanup)
4. ✅ Unregister VHDs when operations complete successfully
5. ✅ Cleanup function handles errors gracefully (best-effort, suppresses errors)

**Pattern:**
```bash
# Initialize cleanup system at script startup (vhdm.sh)
init_resource_cleanup

# Register VHD for cleanup when attaching
register_vhd_cleanup "$vhd_path" "" "$dev_name"

# Update registration with UUID when detected
unregister_vhd_cleanup "$vhd_path"
register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"

# Unregister when operation completes successfully
unregister_vhd_cleanup "$vhd_path"
```

**Functions:**
- `init_resource_cleanup()` - Initialize cleanup system with trap handlers (EXIT, INT, TERM)
- `register_vhd_cleanup(path, uuid, dev_name)` - Register VHD for automatic cleanup
- `unregister_vhd_cleanup(path)` - Unregister VHD from cleanup tracking
- `register_file_cleanup(path)` - Register temporary file for cleanup
- `unregister_file_cleanup(path)` - Unregister file from cleanup tracking
- `cleanup_on_exit()` - Automatic cleanup handler (called on script exit/interrupt)

**Registration Points:**
- `mount_vhd()` - Registers when VHD is attached, unregisters on successful mount
- `attach_vhd()` - Registers when VHD is attached, unregisters on successful completion
- `resize_vhd()` - Registers new VHD when created, unregisters on successful completion

**Cleanup Behavior:**
- On script exit (normal or error): All registered VHDs are detached, all registered files are removed
- On script interrupt (Ctrl+C): Same cleanup as exit
- On script termination (kill): Same cleanup as exit
- Cleanup messages shown unless in quiet mode
- Errors during cleanup are suppressed (best-effort approach)

## Key Implementation Details

### Configuration
**Main Script (`vhdm.sh`):**
- No default configuration values
- All parameters must be provided via command-line options
- Required parameters: `--path`, `--mount-point`, `--name` (depending on command)

**Persistent Disk Tracking:**
- Location: `~/.config/wsl-disk-management/vhd_mapping.json`
- Automatically created on first use
- Tracks VHD path→UUID→mount_points associations
- No manual configuration needed

**Test Scripts:**
- Tests source `tests/.env.test` for test environment configuration
- Test configuration: `WSL_DISKS_DIR` (Windows directory for VHD storage), `MOUNT_DIR` (Linux directory for mount points)
- Each test suite dynamically creates unique VHD names: `test_[suite]_disk` (e.g., `test_status_disk`, `test_attach_disk`)
- Mount points are dynamically generated: `${MOUNT_DIR}test_[suite]_disk`
- UUIDs are discovered dynamically at test runtime

**Flags are exported** for use in child scripts: `export QUIET` and `export DEBUG`

### UUID vs Device Names
VHDs are identified primarily by **UUID**, not device names (/dev/sdX), because:
- Device names can change between boots
- UUIDs persist across mount/unmount cycles
- UUIDs change only when formatting, not when attaching/detaching

### UUID Discovery
The system uses deterministic UUID discovery methods with persistent tracking:
- **From tracking file**: `lookup_vhd_uuid()` checks persistent mapping file first (✅ SAFE, FASTEST)
- **From mount point**: `wsl_find_uuid_by_mountpoint()` reverse-lookups UUID from mounted filesystem (✅ SAFE)
- **Snapshot-based device detection**: Compare before/after device lists during attach/create operations, then get UUID from device (✅ SAFE)
- **From path with safety check**: `wsl_find_uuid_by_path()` checks tracking file, validates file exists, counts attached VHDs before discovery
- **Dynamic VHD detection**: `wsl_find_dynamic_vhd_uuid()` finds non-system disks - ⚠️ ONLY safe when exactly one VHD is attached

**Tracking File Priority:**
`wsl_find_uuid_by_path()` always checks the tracking file first. If UUID is found in tracking, it validates the UUID is still attached. This enables safe multi-VHD operations without requiring explicit UUIDs.

Commands that support UUID discovery:
- `status --path` or `status --mount-point`
- `umount --path` or `umount --mount-point`

**Note:** The `format` command does NOT support UUID discovery. It requires either `--uuid` or `--name` to be explicitly provided.

### WSL Integration Commands
- Attach: `wsl.exe --mount --vhd "$path" --bare`
- Detach: `wsl.exe --unmount "$path"`
- Query: `lsblk -f -J | jq` for JSON-parsed block device info
- UUID retrieval: `sudo blkid -s UUID -o value`

### Error Handling for Already-Attached VHDs
If `wsl_attach_vhd` fails (VHD already attached), `mount_vhd()` searches for the UUID by looking for non-system disks matching pattern `sd[d-z]`. This is a fallback mechanism in the mount operation.

### Timing Considerations
After attach/create operations, scripts include `sleep 2` to allow the kernel to recognize new devices. This is necessary for reliable UUID/device detection.

## Development & Testing

### Testing Commands
```bash
# Test mount with already-attached VHD (idempotency)
./vhdm.sh mount --path C:/VMs/test.vhdx

# Test status output formats
./vhdm.sh status --all
./vhdm.sh -q status --all  # Machine-readable
./vhdm.sh -d status --all  # Debug mode (show all commands)
./vhdm.sh -q -d status --all  # Combined (machine-readable + commands)

# Test error handling
./vhdm.sh mount --path C:/NonExistent/disk.vhdx  # Should fail gracefully
```

### Debugging Block Device Issues
```bash
# Use debug mode to see all commands executed
./vhdm.sh -d mount --path C:/VMs/disk.vhdx

# Inspect current block devices
sudo lsblk -J | jq

# Check all UUIDs
sudo blkid -s UUID -o value

# Find processes blocking unmount
sudo lsof +D /mnt/mydisk
```

### Dependencies
- `qemu-img` (Arch: `qemu-img`, Debian: `qemu-utils`) - VHD creation and resize
- `jq` - JSON parsing of lsblk output
- `wsl.exe` - Built-in on WSL2
- `rsync` - Data migration during resize operations
- `du` - Directory size calculation
- `find` - File counting for integrity verification

### Linux and WSL Command Reference

Complete list of all Linux and WSL commands used in the scripts:

**WSL Integration Commands:**
- `wsl.exe --mount --vhd "$path" --bare` - Attach VHD to WSL
- `wsl.exe --unmount "$path"` - Detach VHD from WSL

**Block Device Management:**
- `lsblk -f -J` - List block devices with filesystem info in JSON format
- `lsblk -J` - List block devices in JSON format
- `sudo blkid -s UUID -o value` - Get all disk UUIDs
- `sudo blkid -s UUID -o value "/dev/$device"` - Get UUID for specific device

**JSON Processing:**
- `jq -r '.blockdevices[].name'` - Extract device names
- `jq -r '.blockdevices[] | select(.uuid == $UUID) | .name'` - Find device by UUID
- `jq -r '.blockdevices[] | select(.uuid == $UUID) | .mountpoints[]'` - Get mount points
- `jq -r '.blockdevices[] | select(.uuid == $UUID) | .fsavail'` - Get available space
- `jq -r '.blockdevices[] | select(.uuid == $UUID) | ."fsuse%"'` - Get usage percentage
- `jq -r '.blockdevices[] | select(.mountpoints[] == $MP) | .uuid'` - Find UUID by mount point

**Filesystem Operations:**
- `sudo mount UUID="$uuid" "$mount_point"` - Mount filesystem by UUID
- `sudo umount "$mount_point"` - Unmount filesystem
- `sudo mkfs -t "$fs_type" "/dev/$device"` - Format device with filesystem
- `mkdir -p "$path"` - Create directory recursively

**VHD File Operations:**
- `qemu-img create -f vhdx "$path" "$size"` - Create VHD file
- `qemu-img info --output=json "$path"` - Get VHD information in JSON format
- `rm -f "$path"` - Delete file
- `mv "$old_path" "$new_path"` - Rename/move VHD file (for backup)

**Data Migration (Resize):**
- `rsync -aP --stats "$source/" "$dest/"` - Copy files with progress and stats
- `du -sb "$path"` - Calculate directory size in bytes
- `find "$path" -type f` - Count files in directory

**Process Management:**
- `sudo lsof +D "$mount_point"` - List processes using mount point
- `command -v qemu-img` - Check if command exists

**Text Processing:**
- `wsl_convert_path()` - Convert Windows paths to WSL paths (use this instead of inline sed commands)
- `grep -v "null"` - Filter out null values
- `head -n 1` - Get first line

**Other Utilities:**
- `dirname "$path"` - Get directory portion of path
- `basename "$path"` - Get filename from path
- `sleep N` - Wait N seconds for kernel device recognition

**All commands wrapped with debug_cmd() when DEBUG=true** to show execution before running.

### Test Suite
Comprehensive test suites validating all command functionality:

**Running Tests:**
```bash
./tests/test_all.sh              # Run all test suites
./tests/test_all.sh -v           # All tests with verbose output
./tests/test_status.sh           # Individual suite (concise)
./tests/test_status.sh -v        # Individual suite (verbose)
```

**Test Coverage:**

**test_status.sh (10 tests):**
1. Default status output validation (shows usage)
2. Status lookup by UUID
3. Status lookup by path (VHD must be attached/mounted for successful lookup)
4. Status lookup by mount point
5. Attached-but-not-mounted state detection (sets up state first with mount + filesystem unmount)
6. Show all VHDs (--all flag)
7. Quiet mode machine-readable output
8. Error handling: non-existent path
9. Error handling: non-existent mount point
10. Error handling: non-existent UUID

**test_attach.sh (15 tests):**
1. Attach VHD with --path option
2. Idempotency (attach already-attached VHD)
3. Attach with custom --name parameter
4. Verify attached VHD appears in status
5. Verify VHD not mounted after attach
6. Quiet mode machine-readable output
7. Debug mode shows commands
8. Error handling: non-existent path
9. Error handling: missing --path parameter
10. Detach and re-attach successfully
11. Device detection after attach (device-first, then UUID from device)
12. Device name reported after attach
13. Completion message display
14. Combined quiet + debug mode
15. Windows path with backslashes

**test_mount.sh (10 tests):** Mount operations, idempotency, custom mount points

**test_umount.sh (10 tests):** Unmount operations, cleanup verification, multiple unmount methods

**test_create.sh (10 tests):** VHD creation with various parameters, verification that create doesn't auto-attach

**test_delete.sh (10 tests):** VHD deletion with safety checks and error handling

**test_resize.sh (21 tests):**
1-4: Parameter validation (missing/invalid parameters)
5-9: Helper functions (size calculations, conversion utilities)
10-15: Primary resize operation (data migration, file integrity, backup creation)
16-19: Edge cases (auto-size calculation, multiple resizes, quiet/debug modes)
20-21: Post-resize operations (unmount/remount verification)

See tests/README.md for detailed coverage of all test suites.

**Test Implementation Pattern:**
```bash
run_test "Description" "command" expected_exit_code
# Or for output validation:
run_test "Description" "command | grep -q 'pattern'" 0
```

**Exit Code Expectations:**
- Status queries return 0 on successful information display (even if VHD not found)
- Grep-based tests return 0 when pattern matches, 1 when it doesn't
- File/mount point validation failures provide suggestions and return appropriate codes

**Configuration:**
Tests source `tests/.env.test` for VHD configuration:
- `WSL_DISKS_DIR` - Windows directory where test VHD files are stored (e.g., `C:/aNOS/VMs/wsl_tests/`)
- `MOUNT_DIR` - Linux directory where test VHDs are mounted (e.g., `/home/$USER/wsl_tests/`)
- Each test suite creates unique VHDs: `test_status_disk.vhdx`, `test_attach_disk.vhdx`, etc.
- Mount points are dynamically generated per suite

**UUID Discovery in Tests:**
Tests automatically discover UUIDs dynamically using `get_vhd_uuid()` helper functions:
- Create VHD if it doesn't exist (using `create` command)
- Attach VHD if newly created (using `attach` command)
- Format VHD if newly created to generate UUID (using `format` command)
- Mount VHD to ensure it's available (using `mount` command)
- Query UUID using `status --path` in quiet mode
- Parse UUID using specific regex pattern: `grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'`

**Critical Implementation Note:**
- Use specific UUID regex pattern (not generic parenthesis matching) to avoid extracting error messages
- VHDs must be formatted before they have UUIDs; unformatted VHDs cannot be queried by UUID
- The helper creates/formats VHDs automatically on first test run

This approach eliminates hardcoded UUIDs and ensures tests work with dynamically created VHDs.

**Test Reporting:**
The test suite includes an automated reporting system that tracks test execution results:

**Architecture:**
- **`test_report.json`** - JSON file serving as the source of truth for all test results
- **`test_report.md`** - Markdown report generated from JSON for human-readable viewing
- **`update_test_report.sh`** - Script that updates reports with test suite results

**Features:**
- Individual test result tracking with test numbers, descriptive names, and status (PASSED/FAILED)
- Summary table showing all test suites with status, counts, and duration
- Detailed test result tables for each suite showing every test's status
- Color-coded status indicators (green for passed, red for failed)
- Navigation anchors for easy linking between summary and detailed sections
- Automatic updates after each test run
- Historical data maintained over time

**Test Result Collection:**
Test scripts collect results using the `ALL_TEST_RESULTS` array:
```bash
ALL_TEST_RESULTS=()  # Array to store all test results: "NUM|NAME|STATUS"

# In run_test function:
ALL_TEST_RESULTS+=("$TESTS_RUN|$test_name|PASSED")
# or
ALL_TEST_RESULTS+=("$TESTS_RUN|$test_name|FAILED")
```

**Report Update:**
After test execution, scripts call `update_test_report.sh`:
```bash
# Prepare all test results as pipe-separated string: "NUM|NAME|STATUS|NUM|NAME|STATUS|..."
TEST_RESULTS_STR=""
if [[ ${#ALL_TEST_RESULTS[@]} -gt 0 ]]; then
    TEST_RESULTS_STR=$(IFS='|'; echo "${ALL_TEST_RESULTS[*]}")
fi

bash "$SCRIPT_DIR/update_test_report.sh" \
    --suite "test_status.sh" \
    --status "$OVERALL_STATUS" \
    --run "$TESTS_RUN" \
    --passed "$TESTS_PASSED" \
    --failed "$TESTS_FAILED" \
    --duration "$DURATION" \
    --test-results "$TEST_RESULTS_STR" >/dev/null 2>&1
```

**Report Parameters:**
- `--suite NAME` - Test suite name (e.g., `test_status.sh`)
- `--status STATUS` - Overall status (`PASSED` or `FAILED`)
- `--run COUNT` - Number of tests run
- `--passed COUNT` - Number of tests passed
- `--failed COUNT` - Number of tests failed
- `--duration SEC` - Test execution duration in seconds
- `--test-results LIST` - Pipe-separated list of all test results in format: `"NUM|NAME|STATUS|NUM|NAME|STATUS|..."`
- `--failed-tests LIST` - Pipe-separated list of failed test names (optional, deprecated, for backward compatibility)

**Test Maintenance:**
- Test expectations must match actual VHD state (mounted vs unmounted)
- Update `tests/.env.test` to change test VHD directory or mount directory
- Each test suite automatically creates its own unique VHD file (no manual VHD setup needed)
- UUIDs are discovered dynamically - no manual UUID configuration needed
- Verbose mode aids debugging without modifying test logic
- Tests requiring specific states must set up that state before assertions
- Exit code expectations must match actual command behavior (not assumed behavior)
- Use `sudo umount` for filesystem-only unmount; script's umount command fully detaches VHD
- Each test suite includes `get_vhd_uuid()` helper for dynamic UUID discovery
- Test results are automatically tracked and reported - no manual intervention needed

## Common Modifications

### Adding New Commands
1. Add function in `vhdm.sh` following pattern: `command_verb()`
2. Parse arguments with `while [[ $# -gt 0 ]]` loop
3. Support `QUIET` mode with conditional echo statements
4. Add to main case statement at bottom
5. Update `show_usage()` help text

### Adding Helper Functions

**Function Naming Convention** (see [Architecture Document](copilot-code-architecture.md) for full hierarchy):

- **Primitives** (generic operations): Simple names without prefixes
  - Examples: `mount_filesystem()`, `umount_filesystem()`, `create_mount_point()`, `convert_size_to_bytes()`
  - Generic Linux operations, no WSL-specific logic
  - Return 0 on success, 1 on failure
  - Minimal error handling
  
- **WSL Helpers** (comprehensive operations): Use `wsl_` prefix
  - Examples: `wsl_mount_vhd()`, `wsl_umount_vhd()`, `wsl_attach_vhd()`, `wsl_detach_vhd()`
  - WSL-specific operations with comprehensive error handling and diagnostics
  - May call primitive functions internally
  - Return 0 on success, 1 on failure

- **Command Functions** (user-facing): Simple verb names
  - Examples: `attach_vhd()`, `mount_vhd()`, `detach_vhd()`, `umount_vhd()`
  - May orchestrate multiple operations (e.g., `mount_vhd()` = attach + mount)
  - Exit on errors using `error_exit()` function (not direct `exit 1`)
  - Comprehensive user-facing error messages via `error_exit()`

**Guidelines for new functions:**
1. Add clear doc comment describing purpose, parameters, return values
2. Follow naming convention for appropriate layer
3. Primitives: Minimal error handling, single operation
4. WSL Helpers: Comprehensive error handling, may call primitives
5. Commands: May orchestrate multiple operations, user-friendly output
6. **Use standardized variable names** in command functions (see [Architecture Document](copilot-code-architecture.md#standardized-variable-naming-conventions)):
   - `vhd_path` for VHD file paths (Windows format)
   - `uuid` for VHD UUIDs
   - `mount_point` for mount point paths
   - `dev_name` for device names (without `/dev/` prefix)
   - `dev_name` for device names
7. **Validate all user inputs** using validation functions from `libs/utils.sh`:
   - `validate_windows_path()` for Windows paths
   - `validate_uuid()` for UUIDs
   - `validate_mount_point()` for mount points
   - `validate_device_name()` for device names
   - `validate_device_name()` for device names
   - `validate_size_string()` for size strings
   - `validate_filesystem_type()` for filesystem types
7. **Use centralized error handling functions** from `libs/utils.sh`:
   - **Command functions**: Always use `error_exit()` instead of `return 1` or direct `exit 1`
     - Example: `error_exit "Invalid path format: $path" 1 "Path must be a valid Windows path"`
   - **Helper functions**: Use `return 1` directly (or `error_return()` if you need logging)
     - Example: `log_error "Operation failed"; return 1`
8. Use structured logging functions instead of echo statements:
   - `log_debug()` for debug messages
   - `log_info()` for informational messages
   - `log_warn()` for warnings
   - `log_error()` for errors
   - `log_success()` for success messages
9. Respect `DEBUG` and `QUIET` flags (logging functions handle this automatically)

### Path Conversion
Path conversion is centralized in `libs/utils.sh`:
```bash
wsl_convert_path() {
    local win_path="$1"
    if [[ -z "$win_path" ]]; then
        return 1
    fi
    # Convert drive letter to lowercase and prepend /mnt/
    # Convert backslashes to forward slashes
    echo "$win_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g'
}
```

**Always use `wsl_convert_path()` instead of inline sed commands** when converting Windows paths to WSL paths. This ensures consistency and makes future modifications easier.

### Adding New Tests
1. Add test function call in `test_status.sh` following pattern: `run_test "Description" "command" expected_exit_code`
2. Use grep patterns for output validation: `run_test "Test" "command | grep -q 'pattern'" 0`
3. Suppress non-test output: redirect stderr/stdout with `2>&1` or `>/dev/null 2>&1`
4. Increment test numbering sequentially
5. Test both success and error scenarios
6. Verify exit codes match actual command behavior
7. Add verbose output details if needed
8. For optional dependencies (like xfs tools), check availability and skip or adjust test accordingly

## Critical Gotchas

1. **Snapshot timing**: Take snapshots immediately before attach operations. Filter old devices BEFORE sleep to ensure correct pre-attach state. Device detection happens after sleep.
2. **Device-first detection**: Always detect device first (works for formatted and unformatted), then get UUID from device if available
3. **Array passing**: Pass array elements directly as arguments (`"${array[@]}"`) instead of using indirect reference for reliability
2. **Windows path format**: `wsl.exe` commands require Windows paths; filesystem checks require WSL paths
3. **Structured logging**: Use logging functions (`log_info`, `log_error`, etc.) instead of echo statements for consistent, timestamped output
4. **Quiet mode**: Logging functions automatically respect `QUIET` flag (info/warn/success suppressed, errors always shown)
5. **Debug mode**: All command executions use `debug_cmd()` wrapper which calls `log_debug()` internally; debug messages only shown when `DEBUG=true`
5. **UUID invalidation**: Formatting a VHD generates a new UUID; document this in user messages
6. **Sudo requirements**: Mount/umount operations require sudo; helper functions assume this
7. **Already-attached detection**: Mount command has complex fallback logic for detecting already-attached VHDs; maintain this when refactoring
16. **Mount does not format**: Mount command will error if VHD is unformatted, directing user to use format command first
8. **Test exit codes**: Status queries return 1 when VHD not found/not attached; tests must expect actual behavior (0 for success, 1 for not found)
16. **Test environment state**: Test expectations must match actual VHD state (attached/mounted/unmounted); verify state before creating assertions
17. **Test state setup**: Some tests need specific states (e.g., attached-but-not-mounted); set up state explicitly before testing
18. **Grep test patterns**: Use `grep -q` for silent pattern matching in tests; return codes are 0 (match) or 1 (no match)
19. **UUID extraction in tests**: Use specific UUID regex `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` instead of generic patterns like `(?<=\().*(?=\))` to avoid extracting error messages from parentheses
20. **VHD formatting requirement**: VHDs must be formatted before they have UUIDs; test helpers should create + attach + format new VHDs automatically
21. **Create command parameters**: The `create` command does NOT accept `--name` parameter (only `--path`, `--size`, `--force`); it only creates the VHD file and does not auto-attach; tests must explicitly call `attach` after `create` if VHD attachment is needed
12. **Test output suppression**: All vhdm.sh calls in tests must suppress non-test output using `2>&1` for commands or `>/dev/null 2>&1` for setup/cleanup operations
13. **Optional test dependencies**: Tests requiring optional tools (xfs, etc.) should check availability and gracefully skip or adjust the test
14. **Filesystem unmount vs detach**: To test "attached but not mounted" state, use `sudo umount` (not the script's umount command which fully detaches)
15. **Flag exports**: QUIET and DEBUG flags must be exported at script initialization for child script access

## Workflow-Specific Notes

**📖 For detailed command flow diagrams and function invocation hierarchies, see [copilot-code-architecture.md](copilot-code-architecture.md)**

### Key Command Behaviors

**Attach** - Single operation: Only attaches VHD to WSL as block device. Does NOT mount to filesystem.
- Uses snapshot-based device detection (device-first, then UUID from device)
- Idempotent (detects already-attached VHDs)
- VHD available as `/dev/sdX` after attach

**Mount** - Orchestration: Attach + mount workflow for user convenience
- Attaches VHD if not already attached
- Verifies VHD is formatted (errors if not)
- Creates mount point if needed
- Mounts to filesystem
- Does NOT auto-format (directs user to format command)

**Format** - Single operation: Only formats device with filesystem
- Requires explicit `--uuid` or `--name` (no path discovery)
- Warns if already formatted (generates new UUID)
- Requires confirmation in non-quiet mode

**Unmount** - Orchestration: Unmount + optional detach
- Unmounts from filesystem
- Detaches from WSL if `--path` provided
- Shows `lsof` diagnostics on failure

**Detach** - Orchestration: Unmount if needed + detach
- Checks if mounted, unmounts first if necessary
- Detaches from WSL
- Requires `--path` for WSL detach operation

**Create** - Single operation: Only creates VHD file
- Does NOT auto-attach or format (separation of concerns)
- Does NOT accept `--name` parameter (only `--path`, `--size`, `--force`)
- Supports `--force` to overwrite existing (with confirmation)
- Tests must explicitly call `attach` after `create` if attachment is needed

**Delete** - Single operation: Only deletes VHD file
- Requires VHD to be detached first (safety check)
- Requires confirmation unless `--force`

**Resize** - Complex orchestration: 10+ step workflow
- Creates new VHD, migrates data, preserves original as backup
- Verifies integrity via file count comparison
- Auto-calculates minimum size (data + 30%)

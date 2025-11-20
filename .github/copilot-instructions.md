# Copilot Instructions - WSL VHD Disk Management

## Project Overview

Bash scripts for managing VHD/VHDX files in Windows Subsystem for Linux (WSL2). Multi-script architecture:
- `disk_management.sh` - Comprehensive CLI for VHD operations (attach, mount, umount, detach, status, create, delete, resize)
- `mount_disk.sh` - Idempotent utility script for ensuring disk is mounted
- `libs/wsl_helpers.sh` - Shared WSL-specific function library
- `libs/utils.sh` - Shared utility functions for size calculations and conversions

Both `disk_management.sh` and `mount_disk.sh` source `libs/wsl_helpers.sh` and `libs/utils.sh` for core functionality.

## Architecture & Core Patterns

### Snapshot-Based Device Detection
When attaching VHDs, the scripts capture before/after snapshots of block devices and UUIDs to identify newly attached disks:
```bash
local old_uuids=($(wsl_get_disk_uuids))
local old_devs=($(wsl_get_block_devices))
# ... attach operation ...
local new_uuids=($(wsl_get_disk_uuids))
# Compare to find the new UUID
```

This pattern is critical in `mount_vhd()` and `wsl_create_vhd()`. System disks (sda/sdb/sdc) are WSL system volumes; dynamically attached VHDs typically appear as sd[d-z].

### Path Format Handling
- **User input**: Windows format with forward slashes: `C:/VMs/disk.vhdx`
- **Internal WSL operations**: Convert to `/mnt/c/VMs/disk.vhdx` using: `sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g'`
- **WSL.exe calls**: Use original Windows format
- **Mount operations**: Standard Linux paths `/mnt/...` or `/home/...`

### Dual Output Modes
Functions must support both verbose and quiet modes using `QUIET` flag:
```bash
[[ "$QUIET" == "false" ]] && echo "User-friendly message"
[[ "$QUIET" == "true" ]] && echo "machine-readable: status"
```
Quiet mode outputs parseable status strings like `path (uuid): attached,mounted`.

### Debug Mode
Scripts support debug mode via `DEBUG` flag (enabled with `-d` or `--debug`):
- **Purpose**: Shows all Linux and WSL commands before execution for troubleshooting
- **Implementation**: `debug_cmd()` wrapper function in `wsl_helpers.sh` prints commands to stderr when `DEBUG=true`
- **Output format**: `[DEBUG] command args...` (blue text to stderr)
- **Command coverage**: Wraps all `wsl.exe`, `sudo`, `lsblk`, `jq`, `mkdir`, `rm`, `qemu-img`, `blkid` invocations
- **Pipeline handling**: Complex pipelines show full command for visibility
- **Compatibility**: Works with quiet mode (`-q -d` shows commands but minimal user output)

```bash
# Debug command wrapper usage
debug_cmd sudo mount UUID="$uuid" "$mount_point"

# Manual debug output for pipelines
if [[ "$DEBUG" == "true" ]]; then
    echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq ..." >&2
fi
command | pipeline
```

### State-Check-Then-Operate Pattern
Always check state before operations to handle idempotent behavior:
```bash
if ! wsl_is_vhd_attached "$uuid"; then
    wsl_attach_vhd "$path" "$name"
fi
if ! wsl_is_vhd_mounted "$uuid"; then
    wsl_mount_vhd_by_uuid "$uuid" "$mount_point"
fi
```

## Key Implementation Details

### Configuration
**Main Script (`disk_management.sh`):**
- No default configuration values
- All parameters must be provided via command-line options
- Required parameters: `--path`, `--mount-point`, `--name` (depending on command)

**Test Scripts:**
- Tests source `tests/.env.test` for default VHD configuration
- Test defaults: `WSL_DISKS_DIR`, `VHD_NAME`, `VHD_PATH`, `MOUNT_POINT`
- UUIDs are discovered dynamically at test runtime

**Flags are exported** for use in child scripts: `export QUIET` and `export DEBUG`

### UUID vs Device Names
VHDs are identified primarily by **UUID**, not device names (/dev/sdX), because:
- Device names can change between boots
- UUIDs persist across mount/unmount cycles
- UUIDs change only when formatting, not when attaching/detaching

### UUID Discovery
The system automatically discovers UUIDs when not explicitly provided:
- **From path**: `wsl_find_uuid_by_path()` validates file exists and finds attached non-system disk
- **From mount point**: `wsl_find_uuid_by_mountpoint()` reverse-lookups UUID from mounted filesystem
- **Dynamic VHD detection**: `wsl_find_dynamic_vhd_uuid()` finds non-system disks (sd[d-z])

Commands that support UUID discovery:
- `status --path` or `status --mount-point`
- `umount --path` or `umount --mount-point`

### WSL Integration Commands
- Attach: `wsl.exe --mount --vhd "$path" --bare --name "$name"`
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
./disk_management.sh mount --path C:/VMs/test.vhdx

# Test status output formats
./disk_management.sh status --all
./disk_management.sh -q status --all  # Machine-readable
./disk_management.sh -d status --all  # Debug mode (show all commands)
./disk_management.sh -q -d status --all  # Combined (machine-readable + commands)

# Test error handling
./disk_management.sh mount --path C:/NonExistent/disk.vhdx  # Should fail gracefully
```

### Debugging Block Device Issues
```bash
# Use debug mode to see all commands executed
./disk_management.sh -d mount --path C:/VMs/disk.vhdx

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
- `bc` - Optional: Enhanced arithmetic for size calculations (degrades gracefully)
- `du` - Directory size calculation
- `find` - File counting for integrity verification

### Linux and WSL Command Reference

Complete list of all Linux and WSL commands used in the scripts:

**WSL Integration Commands:**
- `wsl.exe --mount --vhd "$path" --bare --name "$name"` - Attach VHD to WSL
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
- `bc -l` - Arbitrary precision calculator (optional)

**Process Management:**
- `sudo lsof +D "$mount_point"` - List processes using mount point
- `command -v qemu-img` - Check if command exists

**Text Processing:**
- `sed 's|^\([A-Za-z]\):|/mnt/\L\1|'` - Convert Windows drive letter to WSL mount path
- `sed 's|\\\\|/|g'` - Convert backslashes to forward slashes
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
3. Status lookup by path (expects exit code 1 when not attached)
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
11. UUID detection after attach
12. Device name reported after attach
13. Completion message display
14. Combined quiet + debug mode
15. Windows path with backslashes

**test_mount.sh (10 tests):** Mount operations, idempotency, custom mount points

**test_umount.sh (10 tests):** Unmount operations, cleanup verification, multiple unmount methods

**test_create.sh (10 tests):** VHD creation with various parameters, filesystem validation

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
- VHD must exist at `$VHD_PATH`
- Mount point `$MOUNT_POINT` must be configured
- VHD_NAME specifies the name for WSL attachment

**UUID Discovery in Tests:**
Tests automatically discover UUIDs dynamically using `get_vhd_uuid()` helper functions:
- Mount or attach the VHD to ensure it's available
- Query UUID using `status --path` or `status --mount-point` in quiet mode
- Parse UUID from machine-readable output using grep

This approach eliminates hardcoded UUIDs and ensures tests work with any VHD specified in `.env.test`.

**Test Maintenance:**
- Test expectations must match actual VHD state (mounted vs unmounted)
- Update `tests/.env.test` if creating new test VHDs (path, mount point, name)
- UUIDs are discovered dynamically - no manual UUID configuration needed
- Verbose mode aids debugging without modifying test logic
- Tests requiring specific states must set up that state before assertions
- Exit code expectations must match actual command behavior (not assumed behavior)
- Use `sudo umount` for filesystem-only unmount; script's umount command fully detaches VHD
- Each test suite includes `get_vhd_uuid()` helper for dynamic UUID discovery

## Common Modifications

### Adding New Commands
1. Add function in `disk_management.sh` following pattern: `command_verb()`
2. Parse arguments with `while [[ $# -gt 0 ]]` loop
3. Support `QUIET` mode with conditional echo statements
4. Add to main case statement at bottom
5. Update `show_usage()` help text

### Adding Helper Functions

**WSL-specific helpers** (add to `libs/wsl_helpers.sh`):
1. Add with clear doc comment
2. Follow naming: `wsl_<action>_<target>` (e.g., `wsl_mount_vhd_by_uuid`)
3. Return 0 on success, 1 on failure
4. Print errors to stderr: `echo "Error: ..." >&2`
5. Validate required arguments at function start

**Utility helpers** (add to `libs/utils.sh`):
1. Add with clear doc comment describing purpose and parameters
2. Follow naming: descriptive function names (e.g., `get_directory_size_bytes`, `convert_size_to_bytes`)
3. Return 0 on success, 1 on failure
4. Echo result to stdout for capture by callers
5. Respect `DEBUG` flag for command visibility when applicable
6. Use for size calculations, format conversions, and general utilities

### Modifying Path Conversion
Path conversion logic appears in multiple places. Consolidate into a helper function if adding more conversions:
```bash
wsl_convert_path() {
    echo "$1" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\\\|/|g'
}
```

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

1. **Snapshot timing**: Take snapshots immediately before/after attach operations, not earlier
2. **Windows path format**: `wsl.exe` commands require Windows paths; filesystem checks require WSL paths
3. **Quiet mode completeness**: Every user-facing echo must have a quiet mode alternative
4. **Debug mode implementation**: All command executions must use `debug_cmd` wrapper or manual debug output; debug messages go to stderr
5. **UUID invalidation**: Formatting a VHD generates a new UUID; document this in user messages
6. **Sudo requirements**: Mount/umount operations require sudo; helper functions assume this
7. **Already-attached detection**: Mount command has complex fallback logic for detecting already-attached VHDs; maintain this when refactoring
8. **Test exit codes**: Status queries return 1 when VHD not found/not attached; tests must expect actual behavior (0 for success, 1 for not found)
9. **Test environment state**: Test expectations must match actual VHD state (attached/mounted/unmounted); verify state before creating assertions
10. **Test state setup**: Some tests need specific states (e.g., attached-but-not-mounted); set up state explicitly before testing
11. **Grep test patterns**: Use `grep -q` for silent pattern matching in tests; return codes are 0 (match) or 1 (no match)
12. **Test output suppression**: All disk_management.sh calls in tests must suppress non-test output using `2>&1` for commands or `>/dev/null 2>&1` for setup/cleanup operations
13. **Optional test dependencies**: Tests requiring optional tools (xfs, etc.) should check availability and gracefully skip or adjust the test
14. **Filesystem unmount vs detach**: To test "attached but not mounted" state, use `sudo umount` (not the script's umount command which fully detaches)
15. **Flag exports**: QUIET and DEBUG flags must be exported at script initialization for child script access

## Workflow-Specific Notes

### Mount Operation Flow
1. Parse args → 2. Check VHD file exists (WSL path) → 3. Snapshot → 4. Attach (or detect existing) → 5. Detect UUID → 6. Check mount status → 7. Mount if needed

Critical: Steps 4-5 have fallback logic for already-attached VHDs.

### Create Operation Flow  
1. Parse args → 2. Convert path → 3. Check doesn't exist → 4. Create dirs → 5. Verify qemu-img → 6. Snapshot → 7. Create with qemu-img → 8. Attach → 9. Detect device → 10. Format → 11. Return UUID

Note: VHD is left in attached-but-not-mounted state; user must mount separately.

### Unmount Operation Flow
1. Parse args → 2. Check attached → 3. Unmount from filesystem → 4. Detach from WSL → 5. Verify detached

Error handling: If unmount fails, suggest `lsof +D` to find blocking processes.

### Attach Operation Flow
1. Parse args (path, name) → 2. Validate VHD file exists → 3. Snapshot UUIDs/devices → 4. Attempt attach → 5. Detect new UUID → 6. Report device name → 7. Return success

Critical: Attach does NOT mount to filesystem - VHD is only available as block device. Has fallback logic for already-attached VHDs (idempotency). UUID detection uses snapshot-based device comparison.

### Resize Operation Flow
1. Parse args (mount-point, size) → 2. Validate mount point exists and is mounted → 3. Calculate directory size → 4. Determine target size (max of requested size or data+30%) → 5. Create new VHD with target size → 6. Mount new VHD to temporary location → 7. Copy all data with rsync → 8. Verify file counts match → 9. Unmount both disks → 10. Backup original VHD (rename with _bkp suffix) → 11. Rename new VHD to original name → 12. Remount at original location → 13. Verify integrity → 14. Return new UUID

Critical: Original VHD is preserved as backup. Data migration uses rsync with progress reporting. Size calculation ensures disk is large enough for data plus 30% overhead. File count verification ensures data integrity.

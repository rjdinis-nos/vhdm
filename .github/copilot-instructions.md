# Copilot Instructions - WSL VHD Disk Management

## Project Overview

Bash scripts for managing VHD/VHDX files in Windows Subsystem for Linux (WSL2). Two-script architecture: `disk_management.sh` (CLI) sources `libs/wsl_helpers.sh` (function library).

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

### Configuration Defaults
Located at top of `disk_management.sh`:
```bash
WSL_DISKS_DIR="C:/aNOS/VMs/wsl_disks/"
VHD_PATH="${WSL_DISKS_DIR}disk.vhdx"
VHD_UUID="57fd0f3a-4077-44b8-91ba-5abdee575293"
MOUNT_POINT="/home/rjdinis/disk"
```
These are environment-specific and should be parameterized in new deployments.

### UUID vs Device Names
VHDs are identified primarily by **UUID**, not device names (/dev/sdX), because:
- Device names can change between boots
- UUIDs persist across mount/unmount cycles
- UUIDs change only when formatting, not when attaching/detaching

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

# Test error handling
./disk_management.sh mount --path C:/NonExistent/disk.vhdx  # Should fail gracefully
```

### Debugging Block Device Issues
```bash
# Inspect current block devices
sudo lsblk -J | jq

# Check all UUIDs
sudo blkid -s UUID -o value

# Find processes blocking unmount
sudo lsof +D /mnt/mydisk
```

### Dependencies
- `qemu-img` (Arch: `qemu-img`, Debian: `qemu-utils`) - VHD creation
- `jq` - JSON parsing of lsblk output
- `wsl.exe` - Built-in on WSL2

### Test Suite (tests/test_status.sh)
Comprehensive test suite validating status command functionality:

**Running Tests:**
```bash
./tests/test_status.sh           # Concise output (CI-friendly)
./tests/test_status.sh -v        # Verbose output (development)
```

**Test Coverage (10 tests):**
1. Default status output validation
2. Status lookup by UUID
3. Status lookup by path (with file existence check)
4. Status lookup by mount point (using wsl_find_uuid_by_mountpoint)
5. Attached-but-not-mounted state detection (grep pattern matching)
6. Show all VHDs (--all flag)
7. Quiet mode machine-readable output
8. Error handling: non-existent path
9. Error handling: non-existent mount point
10. Error handling: non-existent UUID

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
Tests source `tests/.env.test` for VHD configuration. Ensure test environment matches:
- VHD exists at `$VHD_PATH`
- VHD has correct `$VHD_UUID`
- Mount point `$MOUNT_POINT` is configured

**Test Maintenance:**
- Test expectations must match actual VHD state (mounted vs unmounted)
- Update `tests/.env.test` if creating new test VHDs
- Verbose mode aids debugging without modifying test logic

## Common Modifications

### Adding New Commands
1. Add function in `disk_management.sh` following pattern: `command_verb()`
2. Parse arguments with `while [[ $# -gt 0 ]]` loop
3. Support `QUIET` mode with conditional echo statements
4. Add to main case statement at bottom
5. Update `show_usage()` help text

### Adding Helper Functions
1. Add to `libs/wsl_helpers.sh` with clear doc comment
2. Follow naming: `wsl_<action>_<target>` (e.g., `wsl_mount_vhd_by_uuid`)
3. Return 0 on success, 1 on failure
4. Print errors to stderr: `echo "Error: ..." >&2`
5. Validate required arguments at function start

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
3. Increment test numbering sequentially
4. Test both success and error scenarios
5. Verify exit codes match actual command behavior
6. Add verbose output details if needed

## Critical Gotchas

1. **Snapshot timing**: Take snapshots immediately before/after attach operations, not earlier
2. **Windows path format**: `wsl.exe` commands require Windows paths; filesystem checks require WSL paths
3. **Quiet mode completeness**: Every user-facing echo must have a quiet mode alternative
4. **UUID invalidation**: Formatting a VHD generates a new UUID; document this in user messages
5. **Sudo requirements**: Mount/umount operations require sudo; helper functions assume this
6. **Already-attached detection**: Mount command has complex fallback logic for detecting already-attached VHDs; maintain this when refactoring
7. **Test exit codes**: Status queries return 0 even when VHD not found (successful info display); tests must expect actual behavior, not assumed errors
8. **Test environment state**: Test expectations must match actual VHD state (attached/mounted/unmounted); verify state before creating assertions
9. **Grep test patterns**: Use `grep -q` for silent pattern matching in tests; return codes are 0 (match) or 1 (no match)

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

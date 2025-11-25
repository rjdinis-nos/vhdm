# WSL VHD Disk Management - Code Architecture

## High-Level Architecture

### System Components

The system is organized into three architectural layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    USER COMMANDS LAYER                      │
│  disk_management.sh: CLI commands (attach, mount, format,  │
│                      umount, detach, status, create,        │
│                      delete, resize)                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   WSL HELPERS LAYER                         │
│  libs/wsl_helpers.sh: WSL-specific operations with          │
│                       comprehensive error handling           │
│  - wsl_attach_vhd(), wsl_detach_vhd()                      │
│  - wsl_mount_vhd(), wsl_umount_vhd()                       │
│  - wsl_is_vhd_attached(), wsl_is_vhd_mounted()             │
│  - wsl_get_vhd_info(), wsl_find_uuid_*()                   │
│  - format_vhd(), wsl_create_vhd(), wsl_delete_vhd()        │
│  - handle_uuid_discovery_result(), detect_new_uuid_after_attach() │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   PRIMITIVES LAYER                          │
│  libs/wsl_helpers.sh & libs/utils.sh:                      │
│  - create_mount_point(), mount_filesystem()                │
│  - umount_filesystem()                                      │
│  - convert_size_to_bytes(), bytes_to_human()               │
│  - get_directory_size_bytes()                              │
│  - wsl_get_block_devices(), wsl_get_disk_uuids()          │
│  - validate_windows_path(), validate_uuid()               │
│  - validate_mount_point(), validate_device_name()         │
│  - validate_size_string()                                │
│  - validate_filesystem_type(), sanitize_string()          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   SYSTEM LAYER                              │
│  - wsl.exe (Windows Subsystem for Linux)                   │
│  - Linux kernel (mount, umount, lsblk, blkid)             │
│  - qemu-img (VHD file operations)                          │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Layered Architecture**: Each layer has specific responsibilities and can only call functions from its own layer or layers below
2. **Single Responsibility at Primitive Level**: Primitives do one thing only
3. **Orchestration at Command Level**: User commands may combine multiple operations for complete workflows
4. **Consistent Error Handling**: WSL helpers provide comprehensive diagnostics; primitives just execute
5. **State-Check-Then-Operate**: Always verify current state before attempting operations
6. **Deterministic UUID Resolution**: Never use heuristics or guessing to identify disks (see Critical Rule below)
7. **Persistent State Tracking**: Path→UUID mappings persist across sessions for fast, deterministic lookup

## Critical Rule: No Heuristic Disk Discovery

**NEVER use non-deterministic heuristics to identify which VHD/disk to operate on.**

### The Problem
WSL does not provide a direct path→UUID mapping after attachment. This creates temptation to "guess" which disk is the target by using patterns like:
- "Find the first non-system disk (sd[d-z])"
- "Assume the most recent disk is the target"
- "Pick any disk that matches a pattern"

**These approaches FAIL when multiple VHDs are attached**, causing operations on the wrong disk.

### Allowed UUID Discovery Methods

✅ **SAFE - Deterministic Methods (in priority order):**
1. **Persistent tracking file by path**: `lookup_vhd_uuid()` checks `~/.config/wsl-disk-management/vhd_mapping.json` first (FASTEST)
2. **Persistent tracking file by device name**: `lookup_vhd_uuid_by_dev_name()` queries by device name
3. **UUID from mount point**: `findmnt` or `lsblk` lookup of mounted filesystem
4. **Snapshot-based detection during attach/create**: Compare before/after disk lists immediately after WSL attach operation
5. **Explicit user-provided UUID**: User specifies `--uuid` parameter

❌ **FORBIDDEN - Non-Deterministic Methods:**
1. ~~Find first `sd[d-z]` device~~ (arbitrary selection with multiple VHDs)
2. ~~Assume path validation + any dynamic disk = target~~ (no verification)
3. ~~Loop through all UUIDs and pick first non-system one~~ (random selection)
4. ~~"Most recent" or "only" dynamic VHD assumptions~~ (breaks with multiple disks)

### Implementation Requirements

**When UUID is unknown and cannot be determined safely:**
1. **Count attached dynamic VHDs** using `wsl_count_dynamic_vhds()`
2. **If count > 1**: Require explicit `--uuid` parameter or fail with clear error
3. **If count == 0**: Report "no VHDs attached"
4. **If count == 1**: ONLY THEN use `wsl_find_dynamic_vhd_uuid()` safely

**Example safe implementation:**
```bash
# Safe UUID discovery with multi-VHD detection
wsl_find_uuid_safely_by_path() {
    local path="$1"
    
    # Validate path exists
    [[ ! -e "$path" ]] && return 1
    
    # Count non-system disks
    local count=$(wsl_count_dynamic_vhds)
    
    if [[ $count -gt 1 ]]; then
        echo "Error: Multiple VHDs attached. Specify --uuid explicitly." >&2
        echo "Run './disk_management.sh status --all' to see all UUIDs." >&2
        return 2
    elif [[ $count -eq 0 ]]; then
        return 1  # Not attached
    else
        # Safe: exactly one dynamic VHD
        wsl_find_dynamic_vhd_uuid
    fi
}
```

**Functions affected (must be updated):**
- `wsl_find_uuid_by_path()` - Currently blindly calls `wsl_find_dynamic_vhd_uuid()`
- `mount_vhd()` fallback logic - Currently loops through all UUIDs

### Test Requirements
All tests involving UUID discovery must:
1. Verify behavior with 0, 1, and 2+ attached VHDs
2. Ensure operations fail safely with multiple VHDs (not wrong disk)
3. Validate explicit UUID parameter works with multiple VHDs

## Function Responsibility Matrix

### User Command Functions (disk_management.sh)

| Function | Arguments | Responsibility | Orchestrates | Single Operation? |
|----------|-----------|---------------|--------------|-------------------|
| `attach_vhd()` | `--vhd-path` | Attach VHD to WSL as block device | No | ✅ Yes - only attaches |
| `format_vhd_command()` | `--dev-name` OR `--uuid`, `--type` (optional) | Format attached VHD with filesystem | No | ✅ Yes - only formats |
| `mount_vhd()` | `--vhd-path`, `--mount-point` | Complete mount workflow: attach + mount | Yes | ❌ No - orchestration |
| `umount_vhd()` | `--path` OR `--uuid` OR `--mount-point` | Complete unmount workflow: unmount + detach | Yes | ❌ No - orchestration |
| `detach_vhd()` | `--uuid`, `--path` (optional) | Complete detach workflow: unmount if needed + detach | Yes | ❌ No - orchestration |
| `status_vhd()` | `--path` OR `--uuid` OR `--mount-point` OR `--all` | Display VHD status information | No | ✅ Yes - query only |
| `create_vhd()` | `--path`, `--size` (optional), `--force` (optional) | Create new VHD file | No | ✅ Yes - file creation only |
| `delete_vhd()` | `--path`, `--uuid` (optional), `--force` (optional) | Delete VHD file | No | ✅ Yes - file deletion only |
| `resize_vhd()` | `--mount-point`, `--size` | Complete resize workflow with data migration | Yes | ❌ No - complex orchestration |

### WSL Helper Functions (libs/wsl_helpers.sh)

| Function | Arguments | Responsibility | Calls Primitives | Error Handling |
|----------|-----------|---------------|------------------|----------------|
| `wsl_attach_vhd()` | `$1: path` | Call wsl.exe to attach VHD | No | Minimal |
| `wsl_detach_vhd()` | `$1: path`, `$2: uuid` (optional) | Call wsl.exe to detach VHD | No | Timeout handling |
| `wsl_mount_vhd()` | `$1: uuid`, `$2: mount_point` | Mount VHD by UUID | Yes: `create_mount_point()`, `mount_filesystem()` | Comprehensive |
| `wsl_umount_vhd()` | `$1: mount_point` | Unmount VHD with diagnostics | Yes: `umount_filesystem()` | Comprehensive (lsof) |
| `wsl_is_vhd_attached()` | `$1: uuid` | Check if VHD is attached | No | None (query only) |
| `wsl_is_vhd_mounted()` | `$1: uuid` | Check if VHD is mounted | No | None (query only) |
| `wsl_get_vhd_info()` | `$1: uuid` | Get VHD device information | No | None (query only) |
| `wsl_get_vhd_mount_point()` | `$1: uuid` | Get mount point for UUID | No | None (query only) |
| `wsl_find_uuid_by_path()` | `$1: path` (Windows format) | **SAFE** Discover UUID from VHD path with multi-VHD detection | No | Multi-VHD aware |
| `wsl_find_uuid_by_mountpoint()` | `$1: mount_point` | Discover UUID from mount point | No | None (query only) |
| `wsl_count_dynamic_vhds()` | None | Count non-system disks attached | No | None (query only) |
| `wsl_find_dynamic_vhd_uuid()` | None | **UNSAFE** Find first non-system disk UUID - only use when count==1 | No | None (query only) |
| `format_vhd()` | `$1: device`, `$2: fs_type` (default: "ext4") | Format device with filesystem | No | Minimal |
| `wsl_create_vhd()` | `$1: path`, `$2: size`, `$3: fs_type` (default: "ext4") | Create, attach, and format VHD | Yes: `wsl_attach_vhd()`, `format_vhd()` | Comprehensive |
| `wsl_delete_vhd()` | `$1: path` (Windows format) | Delete VHD file | No | Minimal |
| `wsl_get_block_devices()` | None | List all block devices | No | None (query only) |
| `wsl_get_disk_uuids()` | None | List all disk UUIDs | No | None (query only) |
| `init_disk_tracking_file()` | None | Initialize tracking file structure | No | None (setup only) |
| `normalize_vhd_path()` | `$1: path` (Windows format) | Normalize path for consistent tracking | No | None (transform only) |
| `save_vhd_mapping()` | `$1: path`, `$2: uuid`, `$3: mount_points` (optional) | Save/update path→UUID mapping | No | Minimal |
| `lookup_vhd_uuid()` | `$1: path` (Windows format) | Retrieve UUID from tracking file | No | None (query only) |
| `update_vhd_mount_points()` | `$1: path`, `$2: mount_points` (comma-separated) | Update mount points for existing mapping | No | Minimal |
| `remove_vhd_mapping()` | `$1: path` (Windows format) | Remove mapping from tracking file | No | Minimal |

### Primitive Functions (libs/wsl_helpers.sh & libs/utils.sh)

| Function | Arguments | Responsibility | Library | Purpose |
|----------|-----------|---------------|---------|---------|
| `create_mount_point()` | `$1: mount_point` | Create directory with mkdir -p | wsl_helpers.sh | Directory creation |
| `mount_filesystem()` | `$1: uuid`, `$2: mount_point` | Execute sudo mount UUID=... | wsl_helpers.sh | Filesystem mount |
| `umount_filesystem()` | `$1: mount_point` | Execute sudo umount | wsl_helpers.sh | Filesystem unmount |
| `convert_size_to_bytes()` | `$1: size_string` (e.g., "1G", "500M") | Convert size string to bytes | utils.sh | Size calculation |
| `bytes_to_human()` | `$1: bytes` | Convert bytes to human readable | utils.sh | Size formatting |
| `get_directory_size_bytes()` | `$1: directory_path` | Calculate directory size | utils.sh | Size query |
| `validate_windows_path()` | `$1: path` | Validate Windows path format, reject dangerous patterns | utils.sh | Input validation (security) |
| `validate_uuid()` | `$1: uuid` | Validate UUID format (RFC 4122) | utils.sh | Input validation (security) |
| `validate_mount_point()` | `$1: mount_point` | Validate mount point path | utils.sh | Input validation (security) |
| `validate_device_name()` | `$1: device` | Validate device name pattern | utils.sh | Input validation (security) |
| `validate_size_string()` | `$1: size` | Validate size string format | utils.sh | Input validation (security) |
| `validate_filesystem_type()` | `$1: fs_type` | Whitelist validation for filesystem types | utils.sh | Input validation (security) |
| `sanitize_string()` | `$1: input` | Remove control characters (defense in depth) | utils.sh | Input sanitization (security) |
| `log_debug()` | `$@: message` | Log debug message (only when DEBUG=true) | utils.sh | Structured logging |
| `log_info()` | `$@: message` | Log info message (unless QUIET=true) | utils.sh | Structured logging |
| `log_warn()` | `$@: message` | Log warning message (unless QUIET=true) | utils.sh | Structured logging |
| `log_error()` | `$@: message` | Log error message (always shown) | utils.sh | Structured logging |
| `log_success()` | `$@: message` | Log success message (unless QUIET=true) | utils.sh | Structured logging |
| `print_section_header()` | `$1: title` (optional) | Print standardized section header with separator lines | utils.sh | Output formatting |
| `debug_cmd()` | `$@: command and args` | Wrapper to log and execute commands in debug mode | wsl_helpers.sh | Debug support (uses log_debug) |
| `init_resource_cleanup()` | None | Initialize resource cleanup system with trap handlers | utils.sh | Resource management |
| `register_vhd_cleanup()` | `$1: path, $2: uuid, $3: dev_name` | Register VHD for automatic cleanup | utils.sh | Resource management |
| `unregister_vhd_cleanup()` | `$1: path` | Unregister VHD from cleanup tracking | utils.sh | Resource management |
| `register_file_cleanup()` | `$1: file_path` | Register temporary file for cleanup | utils.sh | Resource management |
| `unregister_file_cleanup()` | `$1: file_path` | Unregister file from cleanup tracking | utils.sh | Resource management |
| `cleanup_on_exit()` | None | Automatic cleanup handler (called on EXIT/INT/TERM) | utils.sh | Resource management |

## Function Flow Diagrams

### Attach Command Flow

```
attach_vhd()
├─→ Parse arguments (--path, --name)
├─→ Validate VHD file exists
├─→ Take snapshot: wsl_get_disk_uuids(), wsl_get_block_devices()
├─→ wsl_attach_vhd(path, name)
│   └─→ wsl.exe --mount --vhd --bare
├─→ Detect UUID: detect_new_uuid_after_attach("old_uuids")
├─→ Detect device name (via lsblk + jq)
└─→ Report status (UUID, device name)
```

**Key Point**: Attach is a **single operation** - it only attaches VHD to WSL as a block device. UUID detection is reporting, not a separate operation.

### Mount Command Flow

```
mount_vhd()
├─→ Parse arguments (--path, --mount-point, --name)
├─→ Validate VHD file exists
├─→ Take snapshot: wsl_get_disk_uuids(), wsl_get_block_devices()
├─→ wsl_attach_vhd(path, name)  [may fail if already attached]
│   └─→ wsl.exe --mount --vhd --bare
├─→ Detect UUID: detect_new_uuid_after_attach("old_uuids")
├─→ If UUID not found, try path-based discovery: wsl_find_uuid_by_path()
│   └─→ handle_uuid_discovery_result() for consistent error handling
├─→ Check if UUID found
│   ├─→ Yes: Verify filesystem exists
│   └─→ No: Error - VHD is unformatted
├─→ wsl_is_vhd_mounted(uuid)
│   ├─→ Already mounted: Skip mount step
│   └─→ Not mounted: Continue
├─→ wsl_mount_vhd(uuid, mount_point)
│   ├─→ create_mount_point(mount_point)
│   │   └─→ mkdir -p
│   └─→ mount_filesystem(uuid, mount_point)
│       └─→ sudo mount UUID=...
└─→ Report status
```

**Key Point**: Mount is an **orchestration function** combining attach + mount operations for user convenience.

### Format Command Flow

```
format_vhd_command()
├─→ Parse arguments (--name OR --uuid, --type)
├─→ Validate at least one identifier provided
├─→ If UUID provided:
│   ├─→ Find device name from UUID (lsblk + jq)
│   └─→ Warn if already formatted
├─→ If name provided:
│   ├─→ Validate device exists
│   └─→ Check if already has UUID (formatted)
├─→ Confirmation prompt (non-quiet mode)
├─→ format_vhd(device, fs_type)
│   ├─→ sudo mkfs -t $fs_type /dev/$device
│   └─→ Return new UUID (blkid)
└─→ Report new UUID and status
```

**Key Point**: Format is a **single operation** - only formats the device. Does NOT support UUID discovery from path (explicit device identification required).

### Unmount Command Flow

```
umount_vhd()
├─→ Parse arguments (--path, --uuid, --mount-point)
├─→ Discover UUID if not provided
│   ├─→ From path: wsl_find_uuid_by_path()
│   │   └─→ handle_uuid_discovery_result() for consistent error handling
│   └─→ From mount point: wsl_find_uuid_by_mountpoint()
├─→ wsl_is_vhd_attached(uuid)
│   └─→ Not attached: Return (nothing to do)
├─→ wsl_is_vhd_mounted(uuid)
│   ├─→ Mounted: Continue to unmount
│   └─→ Not mounted: Skip unmount step
├─→ wsl_umount_vhd(mount_point)
│   ├─→ umount_filesystem(mount_point)
│   │   └─→ sudo umount
│   └─→ On failure: Show lsof diagnostics
├─→ If path provided:
│   └─→ wsl_detach_vhd(path, uuid)
│       └─→ wsl.exe --unmount
└─→ Report status
```

**Key Point**: Unmount is an **orchestration function** - unmounts from filesystem AND optionally detaches from WSL if path is provided.

### Detach Command Flow

```
detach_vhd()
├─→ Parse arguments (--uuid, --path)
├─→ Validate UUID is provided
├─→ wsl_is_vhd_attached(uuid)
│   └─→ Not attached: Return (nothing to do)
├─→ wsl_is_vhd_mounted(uuid)
│   ├─→ Mounted: Must unmount first
│   │   ├─→ Get mount point: wsl_get_vhd_mount_point()
│   │   └─→ wsl_umount_vhd(mount_point)
│   │       ├─→ umount_filesystem(mount_point)
│   │       └─→ On failure: Show lsof diagnostics
│   └─→ Not mounted: Continue
├─→ wsl_detach_vhd(path, uuid)
│   └─→ wsl.exe --unmount
└─→ Report status
```

**Key Point**: Detach is an **orchestration function** - unmounts if mounted, then detaches from WSL. Requires path for WSL detach operation.

### Create Command Flow

```
create_vhd()
├─→ Parse arguments (--path, --size, --force)
├─→ Check if VHD exists
│   ├─→ Exists + --force: Handle overwrite
│   │   ├─→ Find UUID if attached
│   │   ├─→ Unmount if mounted
│   │   ├─→ Detach if attached
│   │   ├─→ Confirmation prompt
│   │   └─→ Delete existing file
│   └─→ Exists + no --force: Error
├─→ Verify qemu-img installed
├─→ Create parent directory (mkdir -p)
├─→ qemu-img create -f vhdx
└─→ Report success (file created, not attached)
```

**Key Point**: Create is a **single operation** - only creates VHD file. Does NOT auto-attach or format (separation of concerns).

### Delete Command Flow

```
delete_vhd()
├─→ Parse arguments (--path, --uuid, --force)
├─→ Validate VHD file exists
├─→ Discover UUID from path if not provided
├─→ Check if VHD is attached
│   └─→ Attached: Error (must unmount/detach first)
├─→ Confirmation prompt (unless --force)
├─→ wsl_delete_vhd(path)
│   └─→ rm -f
└─→ Report success
```

**Key Point**: Delete is a **single operation** - only deletes file. Requires VHD to be detached first (safety check).

### Resize Command Flow

```
resize_vhd()
├─→ Parse arguments (--mount-point, --size)
├─→ Validate mount point exists and is mounted
├─→ Find UUID: wsl_find_uuid_by_mountpoint()
├─→ Calculate directory size: get_directory_size_bytes()
├─→ Determine target size (max of requested or data+30%)
├─→ Count files in source disk
├─→ wsl_create_vhd(new_path, size, fs_type, temp_name)
│   ├─→ qemu-img create
│   ├─→ wsl_attach_vhd()
│   ├─→ format_vhd()
│   └─→ Return new UUID
├─→ wsl_mount_vhd(new_uuid, temp_mount_point)
├─→ Copy data: rsync -a source/ dest/
├─→ Verify: Count files in new disk
├─→ Compare file counts (integrity check)
├─→ wsl_umount_vhd(target_mount_point) - unmount source
├─→ wsl_detach_vhd(target_path) - detach source
├─→ Rename source VHD to _bkp
├─→ wsl_umount_vhd(temp_mount_point) - unmount new
├─→ wsl_detach_vhd(new_path) - detach new
├─→ Rename new VHD to target name
├─→ Attach and mount at original location
└─→ Report new UUID and status
```

**Key Point**: Resize is a **complex orchestration** performing 10+ operations. Original VHD preserved as backup. Data integrity verified via file count comparison.

## Function Invocation Hierarchy

### Level 1: User Commands (Entry Points)
- `attach_vhd()` → `wsl_attach_vhd()`
- `format_vhd_command()` → `format_vhd()`
- `mount_vhd()` → `wsl_attach_vhd()` → `wsl_mount_vhd()` → `create_mount_point()` + `mount_filesystem()`
- `umount_vhd()` → `wsl_umount_vhd()` → `umount_filesystem()` + `wsl_detach_vhd()`
- `detach_vhd()` → `wsl_umount_vhd()` + `wsl_detach_vhd()`
- `create_vhd()` → `qemu-img` (direct)
- `delete_vhd()` → `wsl_delete_vhd()` → `rm`
- `resize_vhd()` → orchestrates multiple operations

### Level 2: WSL Helpers (Business Logic)
- `wsl_attach_vhd()` → `wsl.exe --mount`
- `wsl_detach_vhd()` → `wsl.exe --unmount`
- `wsl_mount_vhd()` → `create_mount_point()` + `mount_filesystem()`
- `wsl_umount_vhd()` → `umount_filesystem()` + diagnostics
- `wsl_create_vhd()` → `qemu-img` + `wsl_attach_vhd()` + `format_vhd()`
- `format_vhd()` → `sudo mkfs` + `blkid`

### Level 3: Primitives (Direct Operations)
- `create_mount_point()` → `mkdir -p`
- `mount_filesystem()` → `sudo mount`
- `umount_filesystem()` → `sudo umount`
- `convert_size_to_bytes()` → arithmetic
- `bytes_to_human()` → arithmetic + formatting
- `get_directory_size_bytes()` → `du -sb`

### Level 4: Query Functions (State Inspection)
- `wsl_is_vhd_attached()` → `lsblk -f -J` + `jq`
- `wsl_is_vhd_mounted()` → `lsblk -f -J` + `jq`
- `wsl_get_vhd_info()` → `lsblk -f -J` + `jq`
- `wsl_get_vhd_mount_point()` → `lsblk -f -J` + `jq`
- `wsl_find_uuid_by_path()` → `lookup_vhd_uuid()` → `wsl_find_dynamic_vhd_uuid()` (with multi-VHD safety)
- `wsl_find_uuid_by_mountpoint()` → `lsblk -f -J` + `jq`
- `wsl_get_block_devices()` → `lsblk -J` + `jq`
- `wsl_get_disk_uuids()` → `sudo blkid`

## Key Architectural Patterns

### 1. Persistent Tracking Pattern

Used in: All operations that work with VHD paths

```bash
# Check tracking file first
local uuid=$(lookup_vhd_uuid "$vhd_path")
if [[ -n "$uuid" ]]; then
    # Verify UUID is still attached
    if wsl_is_vhd_attached "$uuid"; then
        # Use tracked UUID
        echo "$uuid"
        return 0
    fi
fi

# Second, try lookup by name (extract name from tracking file first)
local tracked_dev_name=$(jq -r --arg path "$normalized_path" '.mappings[$path].dev_name // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
    if [[ -n "$tracked_dev_name" && "$tracked_dev_name" != "null" ]]; then
        local uuid_by_dev_name=$(lookup_vhd_uuid_by_dev_name "$tracked_dev_name")
        if [[ -n "$uuid_by_dev_name" ]] && wsl_is_vhd_attached "$uuid_by_dev_name"; then
        echo "$uuid_by_name"
        return 0
    fi
fi

# Fall back to device discovery if needed
```

**Purpose**: Fast, deterministic UUID lookup without device scanning. Automatically handles multi-VHD scenarios with path and name-based discovery.

**Operations that save/update tracking:**
- `attach_vhd()` - Saves path→UUID + dev_name after successful attach
- `mount_vhd()` - Updates mount_points after mount
- `umount_vhd()` - Clears mount_points after unmount
- `detach_vhd()` - Clears mount_points when detaching
- `delete_vhd()` - Removes mapping completely
- `wsl_create_vhd()` - Saves mapping after creation and formatting

### 2. Snapshot-Based Detection Pattern

Used in: `attach_vhd()`, `mount_vhd()`, `resize_vhd()`, `wsl_create_vhd()` (as fallback)

**Centralized Implementation**: Use `detect_new_uuid_after_attach()` helper function

```bash
# Before operation
local old_uuids=($(wsl_get_disk_uuids))

# Perform operation (attach/create)
wsl_attach_vhd "$path" "$name"

# Detect new UUID using centralized helper
local detected_uuid
detected_uuid=$(detect_new_uuid_after_attach "old_uuids")
```

**Helper Function**: `detect_new_uuid_after_attach()` in `libs/wsl_helpers.sh`
- Accepts array name containing old UUIDs (or captures current state if not provided)
- Includes sleep delay for kernel device recognition (configurable via `SLEEP_AFTER_ATTACH`)
- Returns UUID via stdout, empty string if not found
- Returns exit code 0 if UUID found, 1 if not found

**Purpose**: Identify newly attached/created disks when UUID is not in tracking file. Used as fallback when tracking lookup fails. Centralized implementation eliminates code duplication.

### 3. UUID Discovery Error Handling Pattern

Used in: `mount_vhd()`, `umount_vhd()`, `attach_vhd()`, `show_status()`

**Centralized Implementation**: Use `handle_uuid_discovery_result()` helper function

```bash
# Discover UUID with multi-VHD safety
local discovery_result
uuid=$(wsl_find_uuid_by_path "$path" 2>&1)
discovery_result=$?

# Handle discovery result with consistent error handling
handle_uuid_discovery_result "$discovery_result" "$uuid" "mount" "$path"
```

**Helper Function**: `handle_uuid_discovery_result()` in `libs/wsl_helpers.sh`
- Args: `$1` - Discovery result (exit code from `wsl_find_uuid_by_path`: 0=found, 1=not found, 2=multiple VHDs)
- Args: `$2` - Discovered UUID (may be empty)
- Args: `$3` - Context message (e.g., "mount", "umount") for error messages
- Args: `$4` - Path (for error messages, optional)
- Returns: 0 if UUID is valid, exits with error otherwise
- Note: This function EXITS on errors (for use in command functions)

**Purpose**: Standardize UUID discovery error handling across all commands. Provides consistent error messages with helpful suggestions. Handles multiple VHDs and UUID not found cases uniformly.

### 4. State-Check-Then-Operate Pattern

Used in: All operation functions

```bash
if ! wsl_is_vhd_attached "$uuid"; then
    wsl_attach_vhd "$path"
fi

if ! wsl_is_vhd_mounted "$uuid"; then
    wsl_mount_vhd "$uuid" "$mount_point"
fi
```

**Purpose**: Idempotent operations - don't fail if already in desired state.

### 5. Path Format Conversion Pattern

Used in: All commands handling paths

```bash
# User provides: C:/VMs/disk.vhdx
# For WSL calls: Use as-is
wsl.exe --mount --vhd "C:/VMs/disk.vhdx"

# For filesystem operations: Convert to /mnt/c/VMs/disk.vhdx
# Always use the centralized wsl_convert_path() function from libs/utils.sh
local vhd_path_wsl
vhd_path_wsl=$(wsl_convert_path "$path")
```

**Purpose**: Handle different path requirements for WSL vs Linux operations.

**Note**: 
- **Always use `wsl_convert_path()` instead of inline sed commands** for consistency and maintainability
- Persistent tracking uses normalized paths (lowercase, forward slashes) for case-insensitive matching

### 6. Structured Logging Pattern

Used in: All functions throughout the codebase

```bash
# Use logging functions instead of echo statements
log_info "User-friendly message"
log_debug "Detailed diagnostic information"
log_error "Error message (always shown)"
log_warn "Warning message"
log_success "Success message"

# Logging functions automatically:
# - Add timestamps: [YYYY-MM-DD HH:MM:SS] [LEVEL] message
# - Respect QUIET flag (info/warn/success suppressed, errors always shown)
# - Respect DEBUG flag (debug messages only when DEBUG=true)
# - Use appropriate colors (blue=debug, yellow=warn, red=error, green=success)
# - Write to optional log file if LOG_FILE environment variable is set
```

**Purpose**: Consistent, timestamped logging with proper log levels and flag handling.

**Logging Functions** (in `libs/utils.sh`):
- `log_debug()` - Debug messages (only when `DEBUG=true`)
- `log_info()` - Informational messages (unless `QUIET=true`)
- `log_warn()` - Warning messages (unless `QUIET=true`)
- `log_error()` - Error messages (always shown, even in quiet mode)
- `log_success()` - Success messages (unless `QUIET=true`)

**Log File Support:**
Set `LOG_FILE` environment variable to write logs to file:
```bash
export LOG_FILE="/var/log/wsl-disk-management.log"
# All messages (except debug when DEBUG=false) written to file
```

**Configuration Variables:**
All configuration is centralized in `config.sh` and can be overridden via environment variables:
- `SLEEP_AFTER_ATTACH` - Sleep delay after attaching VHD (default: 2 seconds) for kernel device recognition
- `DETACH_TIMEOUT` - Timeout for VHD detach operations (default: 30 seconds) to prevent hanging
- `LOG_FILE` - Optional log file path for persistent logging
- `QUIET` - Quiet mode flag (minimal output, machine-readable format)
- `DEBUG` - Debug mode flag (show all commands before execution)

### 7. Dual Output Mode Pattern

Used in: All user commands (for machine-readable output in quiet mode)

```bash
[[ "$QUIET" == "false" ]] && log_info "User-friendly message"
[[ "$QUIET" == "true" ]] && echo "machine-readable: status"
```

**Purpose**: Support both human-readable (via logging) and script-parseable output (quiet mode).

### 8. Debug Command Wrapper Pattern

Used in: All system command invocations

```bash
# Debug command wrapper (uses log_debug internally)
debug_cmd sudo mount UUID="$uuid" "$mount_point"

# For pipelines, use log_debug directly:
log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
lsblk -f -J | jq ...
```

**Purpose**: Show all commands before execution when debugging. The `debug_cmd()` wrapper automatically calls `log_debug()` with the command string, providing consistent timestamped output.

### 9. Input Validation Pattern

Used in: All functions that receive user input

```bash
# Validate inputs before use
if ! validate_windows_path "$vhd_path"; then
    log_error "Invalid Windows path format: $vhd_path"
    log_info "Path must start with drive letter (e.g., C:/VMs/disk.vhdx)"
    return 1
fi

if ! validate_uuid "$uuid"; then
    log_error "Invalid UUID format: $uuid"
    log_info "UUID must match RFC 4122 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    return 1
fi

if ! validate_mount_point "$mount_point"; then
    log_error "Invalid mount point: $mount_point"
    log_info "Mount point must be an absolute path starting with /"
    return 1
fi
```

**Purpose**: Prevent command injection and path traversal vulnerabilities. All user inputs are validated using whitelist patterns before use in commands.

**Validation Functions** (in `libs/utils.sh`):
- `validate_windows_path()` - Windows path format, rejects command injection chars, `..`, control chars
- `validate_uuid()` - RFC 4122 format, exactly 36 hexadecimal characters
- `validate_mount_point()` - Absolute paths starting with `/`, rejects dangerous patterns
- `validate_device_name()` - Pattern `sd[a-z]+`, max 10 characters
- `validate_size_string()` - Pattern `number[K|M|G|T][B]?`, max 20 characters
- `validate_filesystem_type()` - Whitelist: ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat
- `sanitize_string()` - Removes control characters (defense in depth)

**Validation Points:**
- Command argument parsing in `disk_management.sh` (all commands)
- Input parameters in `mount_disk.sh`
- Helper functions in `libs/wsl_helpers.sh` that receive user input

**Defense in Depth:**
1. Validation at command argument parsing
2. Validation in helper functions
3. Validation before command execution
4. Safe command execution (jq uses `--arg` for safe parameter passing)

### 10. Secure Temporary File Handling Pattern

Used in: All functions that create temporary files for atomic file operations (e.g., JSON tracking file updates)

```bash
# Create secure temporary file using mktemp (not PID-based $$)
local temp_file
temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
if [[ $? -ne 0 || -z "$temp_file" ]]; then
    log_debug "Failed to create temporary file"
    return 1
fi

# Set up trap handler to clean up temp file on exit/interrupt
# Use inline trap command to avoid function definition issues
trap "rm -f '$temp_file'" EXIT INT TERM

# Perform operation (e.g., jq to write JSON)
if jq --arg path "$normalized" '.mappings[$path] = {...}' \
      "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
    # Atomic move (mv is atomic on same filesystem)
    mv "$temp_file" "$DISK_TRACKING_FILE"
    trap - EXIT INT TERM  # Remove trap handler on success
    return 0
else
    # Cleanup on error
    rm -f "$temp_file"
    trap - EXIT INT TERM  # Remove trap handler on error
    return 1
fi
```

**Purpose**: 
- **Security**: Use `mktemp` with `XXXXXX` pattern for secure, unpredictable temporary file names (prevents race conditions and information disclosure)
- **Reliability**: Trap handlers ensure cleanup on script interruption (EXIT, INT, TERM signals)
- **Atomicity**: Use `mv` for atomic file updates (prevents corruption if script is interrupted during write)
- **Cleanup**: Explicit cleanup in all code paths plus trap handlers for defense in depth

**Key Requirements**:
1. ✅ Always use `mktemp` with `XXXXXX` pattern (never use `$$` PID-based names)
2. ✅ Set trap handlers for cleanup on interruption
3. ✅ Remove trap handlers after successful operations
4. ✅ Explicit cleanup in all error paths
5. ✅ Use `mv` for atomic file updates (not `cp` + `rm`)

**Functions Using This Pattern**:
- `save_vhd_mapping()` - Updates tracking file with new VHD mappings
- `update_vhd_mount_points()` - Updates mount points for existing VHD
- `remove_vhd_mapping()` - Removes VHD from tracking file
- `save_detach_history()` - Adds detach events to history

### 11. Resource Cleanup Pattern

Used in: All operations that attach VHDs or create temporary resources that need cleanup on script failure/interrupt

```bash
# Initialize cleanup system at script startup (disk_management.sh)
init_resource_cleanup

# Register VHD for cleanup when attaching
register_vhd_cleanup "$vhd_path" "" "$dev_name"

# Update registration with UUID when detected
unregister_vhd_cleanup "$vhd_path"
register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"

# Unregister when operation completes successfully
unregister_vhd_cleanup "$vhd_path"
```

**Purpose**:
- **Reliability**: Ensures VHDs are automatically detached on script failure or interruption (Ctrl+C)
- **Resource Management**: Prevents orphaned VHD attachments that remain after script errors
- **Cleanup Guarantee**: Trap handlers (EXIT, INT, TERM) ensure cleanup even if script is killed
- **Best-Effort**: Cleanup errors are suppressed to prevent masking original errors

**Key Components** (in `libs/utils.sh`):
- `init_resource_cleanup()` - Initializes cleanup system with trap handlers
- `register_vhd_cleanup(path, uuid, dev_name)` - Registers VHD for automatic cleanup
- `unregister_vhd_cleanup(path)` - Unregisters VHD when operation succeeds
- `register_file_cleanup(path)` - Registers temporary files for cleanup
- `unregister_file_cleanup(path)` - Unregisters files when no longer needed
- `cleanup_on_exit()` - Automatic cleanup function called on exit/interrupt
- Global arrays: `CLEANUP_VHDS` and `CLEANUP_FILES`

**Key Requirements**:
1. ✅ Initialize cleanup system at script startup with `init_resource_cleanup()`
2. ✅ Register VHDs immediately after attachment (before any operations that might fail)
3. ✅ Update registration with UUID when detected (for better cleanup)
4. ✅ Unregister VHDs when operations complete successfully
5. ✅ Cleanup function handles errors gracefully (best-effort, suppresses errors)

**Registration Points**:
- `mount_vhd()` - Registers when VHD is attached, unregisters on successful mount
- `attach_vhd()` - Registers when VHD is attached, unregisters on successful completion
- `resize_vhd()` - Registers new VHD when created, unregisters on successful completion

**Cleanup Behavior**:
- On script exit (normal or error): All registered VHDs are detached, all registered files are removed
- On script interrupt (Ctrl+C): Same cleanup as exit
- On script termination (kill): Same cleanup as exit
- Cleanup messages shown unless in quiet mode
- Errors during cleanup are suppressed (best-effort approach)

**Example Flow**:
```bash
# In mount_vhd() function
if wsl_attach_vhd "$mount_path"; then
    # Register immediately after successful attach
    register_vhd_cleanup "$vhd_path" "" "$dev_name"
    
    # ... detect UUID ...
    
    # Update registration with UUID
    unregister_vhd_cleanup "$vhd_path"
    register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"
    
    # ... mount operation ...
    
    if wsl_mount_vhd "$uuid" "$mount_point"; then
        # Unregister on success - operation completed, no cleanup needed
        unregister_vhd_cleanup "$vhd_path"
    fi
fi
```

## State Machine: VHD Lifecycle

```
┌─────────────┐
│   CREATED   │ (File exists, not attached)
│  (on disk)  │
└──────┬──────┘
       │ attach
       ↓
┌─────────────┐
│  ATTACHED   │ (Block device available)
│ (unformatted)│
└──────┬──────┘
       │ format
       ↓
┌─────────────┐
│  ATTACHED   │ (Block device + filesystem)
│ (formatted) │
└──────┬──────┘
       │ mount
       ↓
┌─────────────┐
│   MOUNTED   │ (Accessible in filesystem)
│   (in use)  │
└──────┬──────┘
       │ umount
       ↓
┌─────────────┐
│  ATTACHED   │
│ (formatted) │
└──────┬──────┘
       │ detach
       ↓
┌─────────────┐
│   CREATED   │
│  (on disk)  │
└──────┬──────┘
       │ delete
       ↓
┌─────────────┐
│  DELETED    │
└─────────────┘
```

### Valid State Transitions

| From State | To State | Command(s) |
|------------|----------|------------|
| Created | Attached | `attach` |
| Created | Mounted | `mount` (attach+mount) |
| Attached (unformatted) | Attached (formatted) | `format` |
| Attached (formatted) | Mounted | `mount` (just mount) |
| Mounted | Attached | `umount` (just unmount) |
| Mounted | Created | `umount` (unmount+detach) |
| Attached | Created | `detach` |
| Created | Deleted | `delete` |

## Error Handling Strategy

### Primitive Functions
- Return 0 on success, 1 on failure
- Minimal error messages to stderr
- No diagnostics or suggestions

### WSL Helper Functions
- Return 0 on success, 1 on failure
- Comprehensive error messages with context using `log_error()`
- Diagnostic output (e.g., lsof for unmount failures) using `log_info()`
- Suggestions for resolution using `log_info()` or `log_warn()`
- Use structured logging functions instead of echo statements

### Command Functions
- Exit on errors using `error_exit()` function (not direct `exit 1`)
- User-friendly error messages using `log_error()` via `error_exit()`
- Detailed suggestions for fixes using optional help text parameter
- State validation before operations
- Use structured logging functions for all output
- **Use standardized variable names** (see Standardized Variable Naming Conventions below)

## Standardized Variable Naming Conventions

All command functions in `disk_management.sh` use standardized local variable names for consistency and maintainability:

### Core Variables

- **`vhd_path`**: VHD file path in Windows format (e.g., `C:/VMs/disk.vhdx`)
  - Used in: `attach_vhd()`, `mount_vhd()`, `umount_vhd()`, `detach_vhd()`, `delete_vhd()`, `create_vhd()`, `show_status()`
  - Previously used function-specific names: `attach_path`, `detach_path`, `delete_path`, `create_path`, `umount_path`, `status_path`

- **`uuid`**: VHD filesystem UUID (e.g., `57fd0f3a-4077-44b8-91ba-5abdee575293`)
  - Used in: `attach_vhd()`, `mount_vhd()`, `umount_vhd()`, `detach_vhd()`, `delete_vhd()`, `format_vhd_command()`, `show_status()`
  - Previously used function-specific names: `attach_uuid`, `detach_uuid`, `mount_uuid`, `umount_uuid`, `delete_uuid`, `format_uuid`, `status_uuid`

- **`mount_point`**: Mount point path (e.g., `/mnt/data`)
  - Used in: `mount_vhd()`, `umount_vhd()`, `show_status()`, `resize_vhd()`
  - Previously used function-specific names: `umount_point`, `status_mount_point`
  - Note: `resize_vhd()` uses `target_mount_point` and `temp_mount_point` for clarity (intentionally different)

- **`dev_name`**: Device name without `/dev/` prefix (e.g., `sde`, `sdd`)
  - Used in: `mount_vhd()`, `umount_vhd()`, `detach_vhd()`, `format_vhd_command()`
  - Previously used function-specific names: `detected_dev_name`, `format_name`, `umount_dev_name`, `detach_dev_name`

- **`dev_name`**: Device name for tracking (e.g., `sde`, `sdd`)
  - Used in: `attach_vhd()`, `show_status()`, `umount_vhd()`, `detach_vhd()`
  - Previously used function-specific names: `attach_name`, `status_name`, `umount_name`, `detach_name`

### Benefits of Standardization

1. **Consistency**: All functions use the same variable names for the same concepts
2. **Maintainability**: Easier to understand and modify code across functions
3. **Reduced Errors**: Less confusion when copying code patterns between functions
4. **Code Clarity**: Variable names immediately convey their purpose

### Implementation Notes

- All command functions parse arguments into these standardized local variables
- Helper functions may use different variable names as appropriate for their scope
- Temporary variables (e.g., `vhd_path_wsl`, `found_path`) are allowed for intermediate conversions
- Function-specific variables are acceptable when they represent unique concepts (e.g., `target_mount_point` vs `temp_mount_point` in `resize_vhd()`)
- **Always use `error_exit()` instead of `return 1` or direct `exit 1`**

### Centralized Error Handling Functions

Located in `libs/utils.sh`:

**`error_exit()`** - For command-level functions:
```bash
error_exit() {
    local msg="$1"           # Error message (required)
    local code="${2:-1}"     # Exit code (default: 1)
    local help_text="${3:-}" # Optional help text
    
    log_error "$msg"         # Always log error (even in quiet mode)
    
    # Show help text if provided and not in quiet mode
    if [[ -n "$help_text" ]] && [[ "$QUIET" != "true" ]]; then
        echo "$help_text" >&2
    fi
    
    # Show usage hint if not in quiet mode
    if [[ "$QUIET" != "true" ]]; then
        echo "Use --help for usage information" >&2
    fi
    
    exit "$code"
}
```

**`error_return()`** - For helper functions (if needed):
```bash
error_return() {
    local msg="$1"           # Error message (required)
    local code="${2:-1}"     # Return code (default: 1)
    
    log_error "$msg"         # Always log error (even in quiet mode)
    return "$code"
}
```

### Example: Unmount Error Handling

```bash
# Primitive: umount_filesystem()
umount_filesystem() {
    if sudo umount "$mount_point" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# WSL Helper: wsl_umount_vhd()
wsl_umount_vhd() {
    if umount_filesystem "$mount_point"; then
        return 0
    else
        log_error "Failed to unmount VHD"
        log_info "Tip: Make sure no processes are using the mount point"
        log_info "Checking for processes using the mount point:"
        sudo lsof +D "$mount_point" 2>/dev/null || log_info "  No processes found (or lsof not available)"
        return 1
    fi
}

# Command Function: umount_vhd()
umount_vhd() {
    # ... argument parsing ...
    
    if ! wsl_umount_vhd "$umount_point"; then
        error_exit "Failed to unmount VHD"
    fi
    
    # ... rest of function ...
}
```

### Example: Command Function Error Handling

```bash
# Good: Using error_exit()
mount_vhd() {
    if [[ -z "$mount_path" ]]; then
        error_exit "--path parameter is required" 1 "Usage: $0 mount --path PATH --mount-point MOUNT_POINT"
    fi
    
    if ! validate_windows_path "$mount_path"; then
        error_exit "Invalid path format: $mount_path" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
    fi
    
    # ... rest of function ...
}

# Bad: Direct exit or return
mount_vhd() {
    if [[ -z "$mount_path" ]]; then
        echo -e "${RED}Error: --path is required${NC}" >&2
        return 1  # ❌ WRONG: Command functions should use error_exit()
    fi
}
```

## Dependencies Between Functions

### Direct Dependencies (A calls B)

```
mount_vhd()
  ├─→ wsl_attach_vhd()
  └─→ wsl_mount_vhd()
        ├─→ create_mount_point()
        └─→ mount_filesystem()

umount_vhd()
  ├─→ wsl_umount_vhd()
  │     └─→ umount_filesystem()
  └─→ wsl_detach_vhd()

detach_vhd()
  ├─→ wsl_umount_vhd()
  │     └─→ umount_filesystem()
  └─→ wsl_detach_vhd()

resize_vhd()
  ├─→ wsl_create_vhd()
  │     ├─→ wsl_attach_vhd()
  │     └─→ format_vhd()
  ├─→ wsl_mount_vhd()
  ├─→ wsl_umount_vhd()
  ├─→ wsl_detach_vhd()
  └─→ get_directory_size_bytes()
```

### Query Dependencies (Used for State Checks)

All operation functions depend on:
- `wsl_is_vhd_attached()` - Check attachment state
- `wsl_is_vhd_mounted()` - Check mount state
- `wsl_get_vhd_info()` - Display information
- `wsl_get_vhd_mount_point()` - Find mount location
- `wsl_count_dynamic_vhds()` - Count attached non-system VHDs (safety check)
- `wsl_find_uuid_by_mountpoint()` - Safe UUID discovery from mount point
- `wsl_find_uuid_by_path()` - Multi-VHD aware UUID discovery (requires implementation update)
- `wsl_find_dynamic_vhd_uuid()` - **UNSAFE** - Only use when `wsl_count_dynamic_vhds()` returns 1

## Testing Architecture

### Test Layer Organization

```
tests/test_all.sh (orchestrator)
├─→ test_status.sh (10 tests) - Query operations
├─→ test_attach.sh (15 tests) - Attach operations + idempotency
├─→ test_detach.sh - Detach operations
├─→ test_mount.sh (10 tests) - Mount operations
├─→ test_umount.sh (10 tests) - Unmount operations
├─→ test_format.sh - Format operations
├─→ test_create.sh (10 tests) - VHD creation
├─→ test_delete.sh (10 tests) - VHD deletion
└─→ test_resize.sh (21 tests) - Resize workflow
```

Each test suite validates:
1. Parameter validation
2. Success paths
3. Error handling
4. Idempotency
5. State verification
6. Output modes (quiet, debug)

### Test Reporting System

The test suite includes an automated reporting system that tracks test execution results:

**Architecture:**
- **`test_report.json`** - JSON file serving as the source of truth for all test results
- **`test_report.md`** - Markdown report generated from JSON for human-readable viewing
- **`update_test_report.sh`** - Script that updates reports with test suite results

**Data Flow:**
```
Test Suite Execution
├─→ run_test() collects results in ALL_TEST_RESULTS array
│   └─→ Format: "NUM|NAME|STATUS"
├─→ After all tests complete
│   ├─→ Calculate summary statistics (run, passed, failed, duration)
│   └─→ Call update_test_report.sh with:
│       ├─→ Suite name
│       ├─→ Overall status
│       ├─→ Summary statistics
│       └─→ Individual test results (--test-results parameter)
└─→ update_test_report.sh
    ├─→ Updates test_report.json (source of truth)
    └─→ Generates test_report.md from JSON
```

**Report Features:**
- Individual test result tracking with test numbers, descriptive names, and status
- Summary table showing all test suites with status, counts, and duration
- Detailed test result tables for each suite showing every test's status
- Color-coded status indicators (green for passed, red for failed)
- Navigation anchors for easy linking between summary and detailed sections
- Automatic updates after each test run
- Historical data maintained over time

**Test Result Collection Pattern:**
```bash
# Initialize array to store all test results
ALL_TEST_RESULTS=()  # Format: "NUM|NAME|STATUS"

# In run_test function:
if [[ $exit_code -eq $expected_exit_code ]]; then
    ALL_TEST_RESULTS+=("$TESTS_RUN|$test_name|PASSED")
else
    ALL_TEST_RESULTS+=("$TESTS_RUN|$test_name|FAILED")
fi

# After all tests, prepare and submit results
TEST_RESULTS_STR=$(IFS='|'; echo "${ALL_TEST_RESULTS[*]}")
bash "$SCRIPT_DIR/update_test_report.sh" \
    --suite "test_status.sh" \
    --status "$OVERALL_STATUS" \
    --run "$TESTS_RUN" \
    --passed "$TESTS_PASSED" \
    --failed "$TESTS_FAILED" \
    --duration "$DURATION" \
    --test-results "$TEST_RESULTS_STR"
```

See `.github/copilot-instructions.md` for detailed test coverage information.

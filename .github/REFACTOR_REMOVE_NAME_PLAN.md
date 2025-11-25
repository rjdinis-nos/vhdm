# Refactoring Plan: Remove `name` Parameter and Use `dev_name` in Tracking

## Overview

This plan outlines the steps to remove the `name` (VHD name) parameter from the entire codebase and replace it with `dev_name` (device name) in the tracking file. This simplifies the codebase by removing a user-provided label that isn't used in actual disk operations.

## Current State

### What `name` Currently Does
- **User-provided label** for organizing/tracking VHDs (e.g., "mydisk", "datastore")
- **Stored in tracking file** as `.mappings[$path].name`
- **Used for querying**: `status --name mydisk` → looks up UUID by name
- **Used in history**: Detach history stores name for reference
- **NOT used in disk operations**: `wsl.exe --mount`, `mount`, `mkfs` don't use it

### What `dev_name` Currently Does
- **System-assigned device identifier** (e.g., "sde", "sdd")
- **Discovered from system** after VHD attachment via `lsblk`
- **Used for disk operations**: `format --dev-name sde`, `mount --dev-name sde`
- **Currently stored in tracking file** in some cases, but not consistently

## Proposed Changes

### Tracking File Structure Change
**Before:**
```json
{
  "mappings": {
    "c:/vms/disk.vhdx": {
      "uuid": "uuid-123",
      "name": "mydisk",        // ← Remove this
      "mount_points": "/mnt/data",
      "last_attached": "2025-01-15T10:30:00Z"
    }
  }
}
```

**After:**
```json
{
  "mappings": {
    "c:/vms/disk.vhdx": {
      "uuid": "uuid-123",
      "dev_name": "sde",       // ← Use this instead
      "mount_points": "/mnt/data",
      "last_attached": "2025-01-15T10:30:00Z"
    }
  }
}
```

## Implementation Plan

### Phase 1: Configuration and JQ Queries

#### 1.1 Update `config.sh`
- [ ] Remove `DEFAULT_VHD_NAME` constant (line 62)
- [ ] Remove `MAX_VHD_NAME_LENGTH` constant (line 88)
- [ ] Update `JQ_SAVE_MAPPING` to use `dev_name` instead of `name`:
  ```bash
  # Before: name: $name
  # After: dev_name: $dev_name
  ```
- [ ] Remove `JQ_GET_UUID_BY_NAME` (no longer needed)
- [ ] Update `JQ_GET_NAME_BY_PATH` → `JQ_GET_DEV_NAME_BY_PATH`:
  ```bash
  # Before: .mappings[$path].name // empty
  # After: .mappings[$path].dev_name // empty
  ```
- [ ] Update `JQ_GET_NAME_BY_UUID` → `JQ_GET_DEV_NAME_BY_UUID`:
  ```bash
  # Before: .value.name // empty
  # After: .value.dev_name // empty
  ```
- [ ] Update `JQ_SAVE_DETACH_HISTORY` to use `dev_name` instead of `name`:
  ```bash
  # Before: name: $name
  # After: dev_name: $dev_name
  ```
- [ ] Update `JQ_FORMAT_HISTORY_ENTRY` to use `dev_name` instead of `name`

### Phase 2: Library Functions (`libs/wsl_helpers.sh`)

#### 2.1 Update `save_vhd_mapping()`
- [ ] Change parameter `$4 - VHD name` → `$4 - Device name`
- [ ] Change `local vhd_name="${4:-}"` → `local dev_name="${4:-}"`
- [ ] Remove `validate_vhd_name()` call
- [ ] Add `validate_device_name()` call if `dev_name` is provided
- [ ] Update jq call to use `--arg dev_name` instead of `--arg name`
- [ ] Update log message: "name: $vhd_name" → "dev_name: $dev_name"

#### 2.2 Remove/Replace `lookup_vhd_uuid_by_name()`
- [ ] **Option A**: Remove function entirely (if not needed)
- [ ] **Option B**: Replace with `lookup_vhd_uuid_by_dev_name()`:
  - Change parameter validation from `validate_vhd_name()` to `validate_device_name()`
  - Update jq query to use `.dev_name == $dev_name` instead of `.name == $name`

#### 2.3 Update `wsl_find_uuid_by_path()`
- [ ] Remove name-based lookup fallback (lines 1063-1076)
- [ ] Keep only path-based and device discovery methods

#### 2.4 Update `wsl_detach_vhd()`
- [ ] Change parameter `$3 - VHD name` → `$3 - Device name`
- [ ] Change `local vhd_name="$3"` → `local dev_name="$3"`
- [ ] Update `save_detach_history()` call to use `dev_name`

#### 2.5 Update `save_detach_history()`
- [ ] Change parameter `$3 - VHD name` → `$3 - Device name`
- [ ] Change `local vhd_name="${3:-}"` → `local dev_name="${3:-}"`
- [ ] Update jq call to use `--arg dev_name` instead of `--arg name`
- [ ] Update log message

#### 2.6 Update `wsl_delete_vhd()`
- [ ] Change `local vhd_name` → `local dev_name`
- [ ] Update lookup to use `JQ_GET_DEV_NAME_BY_PATH` instead of `JQ_GET_NAME_BY_PATH`
- [ ] Update `wsl_detach_vhd()` call to pass `dev_name`

#### 2.7 Update `wsl_create_vhd()`
- [ ] Change parameter `$4 - VHD name` → `$4 - Device name` (or remove if not needed)
- [ ] Update `save_vhd_mapping()` call to use `dev_name` instead of `vhd_name`
- [ ] Note: Device name may not be known at creation time, may need to be updated later

#### 2.8 Update `register_vhd_cleanup()` and `unregister_vhd_cleanup()`
- [ ] Check if these functions use `name` parameter
- [ ] Update to use `dev_name` if applicable

### Phase 3: Command Functions (`disk_management.sh`)

#### 3.1 Update `attach_vhd()`
- [ ] Remove `--name` parameter from argument parsing
- [ ] Remove `local name="$VHD_NAME"` variable
- [ ] Remove `validate_vhd_name()` call
- [ ] Update `register_vhd_cleanup()` calls to remove `name` parameter
- [ ] Update `save_vhd_mapping()` calls:
  - Detect `dev_name` after attachment (via `detect_new_device_after_attach()`)
  - Pass `dev_name` instead of `name` to `save_vhd_mapping()`
- [ ] Update log messages to remove name references

#### 3.2 Update `mount_vhd()`
- [ ] Update `save_vhd_mapping()` calls to use `dev_name` instead of `name`
- [ ] Ensure `dev_name` is detected and passed to tracking functions
- [ ] Remove any name-related logic

#### 3.3 Update `show_status()`
- [ ] Remove `--name` parameter from argument parsing
- [ ] Remove `local name=""` variable
- [ ] Remove `lookup_vhd_uuid_by_name()` call
- [ ] Remove name-related error messages and help text
- [ ] Update `show_usage()` to remove `--name` option

#### 3.4 Update `umount_vhd()`
- [ ] Update `wsl_detach_vhd()` calls to pass `dev_name` instead of `name`
- [ ] Get `dev_name` from UUID using `lsblk` lookup before calling `wsl_detach_vhd()`

#### 3.5 Update `detach_vhd()`
- [ ] Update `wsl_detach_vhd()` calls to pass `dev_name` instead of `name`
- [ ] Get `dev_name` from UUID using `lsblk` lookup before calling `wsl_detach_vhd()`

#### 3.6 Update `delete_vhd()`
- [ ] Update any name-related lookups to use `dev_name`
- [ ] Update `wsl_delete_vhd()` calls if needed

#### 3.7 Update `resize_vhd()`
- [ ] Update `target_vhd_name` → `target_dev_name`
- [ ] Update lookups to use `JQ_GET_DEV_NAME_BY_UUID` instead of `JQ_GET_NAME_BY_UUID`
- [ ] Update `wsl_detach_vhd()` calls to pass `dev_name`

#### 3.8 Update `format_vhd_command()`
- [ ] No changes needed (already uses `dev_name`)

#### 3.9 Update `create_vhd()`
- [ ] No changes needed (doesn't use name)

#### 3.10 Update `show_usage()`
- [ ] Remove all `--name` parameter references
- [ ] Remove examples using `--name`
- [ ] Update help text to remove name-related descriptions

### Phase 4: Utility Scripts

#### 4.1 Update `mount_disk.sh`
- [ ] Remove `VHD_NAME` variable (lines 142-143)
- [ ] Remove name generation logic
- [ ] Update `wsl_attach_vhd()` call to remove name parameter (if it accepts one)
- [ ] Note: `wsl_attach_vhd()` doesn't currently accept name, so may be no-op

### Phase 5: Utility Functions (`libs/utils.sh`)

#### 5.1 Remove `validate_vhd_name()`
- [ ] Remove function entirely (lines 168-197)
- [ ] Remove from validation function list in documentation

### Phase 6: Test Files

#### 6.1 Update All Test Files
- [ ] `tests/test_attach.sh`: Remove `--name` parameter usage
- [ ] `tests/test_status.sh`: Remove `--name` parameter usage
- [ ] `tests/test_detach.sh`: Remove `--name` parameter usage
- [ ] `tests/test_umount.sh`: Remove `--name` parameter usage
- [ ] `tests/test_mount.sh`: Remove `--name` parameter usage (if any)
- [ ] Update test helper functions to remove `vhd_name` parameters
- [ ] Update test assertions to check for `dev_name` instead of `name`

### Phase 7: Documentation

#### 7.1 Update `.github/copilot-code-architecture.md`
- [ ] Remove `name` from standardized variable naming conventions
- [ ] Update tracking file structure documentation
- [ ] Remove name-based lookup examples
- [ ] Update function documentation to remove name parameters

#### 7.2 Update `.github/copilot-instructions.md`
- [ ] Remove `validate_vhd_name()` from validation function list
- [ ] Remove name-related examples and patterns

#### 7.3 Update `.cursorrules`
- [ ] Remove `name` from standardized variable list
- [ ] Update tracking file structure description

#### 7.4 Update `README.md`
- [ ] Remove `--name` parameter from all command examples
- [ ] Remove name-based query examples
- [ ] Update tracking file structure description
- [ ] Remove `validate_vhd_name()` from validation functions list

### Phase 8: Migration (Optional)

#### 8.1 Tracking File Migration
- [ ] Create migration script to update existing tracking files:
  - Read existing tracking file
  - For each mapping, if `name` exists but `dev_name` doesn't:
    - Try to get current `dev_name` from UUID (if VHD is attached)
    - Update mapping to use `dev_name` instead of `name`
    - Remove `name` field
  - Save updated tracking file
- [ ] **Note**: This may not be possible if VHDs are not currently attached
- [ ] **Alternative**: Just let old tracking files work with both fields, new saves use `dev_name`

## Considerations and Risks

### Important Considerations

1. **Device Name Instability**: Device names (e.g., "sde") can change between boots or when devices are attached in different orders. This makes tracking by device name less reliable than tracking by user-provided name.

2. **Loss of User-Friendly Queries**: Users will no longer be able to query by friendly name (`status --name mydisk`). They'll need to use:
   - Path: `status --vhd-path C:/VMs/disk.vhdx`
   - UUID: `status --uuid <uuid>`
   - Device name: `status --dev-name sde` (if we add this)

3. **Tracking File Updates**: Existing tracking files will have `name` fields that are no longer used. Consider:
   - Migration script to convert old format
   - Or: Support both formats during transition period

4. **History Compatibility**: Detach history will change format. Old history entries will have `name`, new ones will have `dev_name`.

### Breaking Changes

- **CLI Changes**: `--name` parameter removed from all commands
- **Tracking File Format**: `name` field replaced with `dev_name`
- **API Changes**: Helper functions no longer accept `name` parameter

### Testing Requirements

- [ ] Test attach without name parameter
- [ ] Test status without name parameter
- [ ] Test tracking file saves `dev_name` correctly
- [ ] Test lookup by device name (if implemented)
- [ ] Test detach history with `dev_name`
- [ ] Test migration of existing tracking files (if implemented)
- [ ] Test with multiple VHDs attached
- [ ] Test device name changes between boots

## Implementation Order

1. **Phase 1**: Configuration (JQ queries) - Foundation
2. **Phase 2**: Library functions - Core functionality
3. **Phase 3**: Command functions - User-facing changes
4. **Phase 4**: Utility scripts - Supporting scripts
5. **Phase 5**: Utility functions - Cleanup
6. **Phase 6**: Tests - Validation
7. **Phase 7**: Documentation - User/developer docs
8. **Phase 8**: Migration - Optional data migration

## Estimated Impact

- **Files to modify**: ~15-20 files
- **Functions to update**: ~20-30 functions
- **Lines of code to change**: ~200-300 lines
- **Breaking changes**: Yes (CLI parameter removal)
- **Migration needed**: Yes (tracking file format change)

## Alternative Consideration

**Alternative Approach**: Keep `name` but make it optional and use `dev_name` as fallback:
- If user provides `--name`, use it for tracking
- If not provided, use `dev_name` for tracking
- This maintains backward compatibility while simplifying for users who don't need custom names

However, since you specifically requested removal, this plan follows the removal approach.


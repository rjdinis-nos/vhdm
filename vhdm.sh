#!/bin/bash

# Get the absolute path to the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration file
if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
    source "$SCRIPT_DIR/config.sh"
fi

# Source helper functions (utils.sh first for validation functions)
# Preserve original SCRIPT_DIR before sourcing (libs may overwrite it)
ORIGINAL_SCRIPT_DIR="$SCRIPT_DIR"
source "$ORIGINAL_SCRIPT_DIR/libs/utils.sh"
source "$ORIGINAL_SCRIPT_DIR/libs/wsl_vhd_mngt.sh"
# Restore SCRIPT_DIR for this script's use (must be done before init_resource_cleanup)
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# Initialize runtime flags (can be overridden by command-line options)
QUIET="${QUIET:-false}"
DEBUG="${DEBUG:-false}"
YES="${YES:-false}"

# Export flags for child scripts
export QUIET
export DEBUG
export YES

# Initialize resource cleanup system (for automatic cleanup on exit/interrupt)
# Note: This must be called after SCRIPT_DIR is restored to avoid path issues
init_resource_cleanup

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] COMMAND [COMMAND_OPTIONS]"
    echo
    echo "Options:"
    echo "  -q, --quiet  - Run in quiet mode (minimal output)"
    echo "  -d, --debug  - Run in debug mode (show all commands before execution)"
    echo "  -y, --yes    - Automatically answer 'yes' to all confirmation prompts"
    echo
    echo "Commands:"
    echo "  attach [OPTIONS]         - Attach a VHD to WSL (without mounting to filesystem)"
    echo "  format [OPTIONS]         - Format an attached VHD with a filesystem"
    echo "  mount [OPTIONS]          - Attach and mount a formatted VHD disk"
    echo "  umount [OPTIONS]         - Unmount and detach the VHD disk"
    echo "  detach [OPTIONS]         - Detach a VHD disk (unmounts first if needed)"
    echo "  status [OPTIONS]         - Show current VHD disk status"
    echo "  create [OPTIONS]         - Create a new VHD disk"
    echo "  delete [OPTIONS]         - Delete a VHD disk file"
    echo "  resize [OPTIONS]         - Resize a VHD disk by creating new disk and migrating data"
    echo "  history [OPTIONS]        - Show detach history"
    echo
    echo "Attach Command Options:"
    echo "  --vhd-path PATH           - [mandatory] VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    echo "  Note: Attaches VHD to WSL without mounting to filesystem."
    echo "        VHD will be accessible as a block device (/dev/sdX) after attachment."
    echo
    echo "Format Command Options:"
    echo "  --dev-name NAME          - [optional] VHD device block name (e.g., sdd, sde)"
    echo "  --uuid UUID              - [optional] VHD UUID"
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    echo "  --type TYPE              - [optional] Filesystem type (ext4, ext3, xfs, etc.) [default: $default_fs]"
    echo "  Note: Either --uuid or --dev-name must be provided."
    echo "        VHD must be attached before formatting. Use 'attach' command first."
    echo "        If --uuid is provided for an already-formatted disk, confirmation will be required."
    echo
    echo "Mount Command Options:"
    echo "  --mount-point PATH       - [mandatory] Mount point path"
    echo "  --vhd-path PATH          - [optional] VHD file path (Windows format)"
    echo "  --dev-name DEVICE        - [optional] Device name (e.g., sde)"
    echo "  Note: Either --vhd-path or --dev-name must be provided."
    echo "        VHD must be formatted before mounting. Use 'format' command if needed."
    echo
    echo "Umount Command Options:"
    echo "  --vhd-path PATH           - [optional] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path or mount-point)"
    echo "  --mount-point PATH       - [optional] Mount point path (UUID will be discovered)"
    echo "  Note: Provide at least one option. UUID will be auto-discovered when possible."
    echo
    echo "Detach Command Options:"
    echo "  --dev-name DEVICE        - [optional] VHD device name (e.g., sde) - alternative to --uuid or --vhd-path"
    echo "  --uuid UUID              - [optional] VHD UUID - alternative to --dev-name or --vhd-path"
    echo "  --vhd-path PATH          - [optional] VHD file path - alternative to --dev-name or --uuid"
    echo "  Note: Either --dev-name, --uuid, or --vhd-path must be provided. If VHD is mounted, it will be unmounted first."
    echo
    echo "Status Command Options:"
    echo "  --vhd-path PATH           - [optional] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path or mount-point)"
    echo "  --mount-point PATH       - [optional] Mount point path (UUID will be discovered)"
    echo "  --all                    - [optional] Show all attached VHDs"
    echo
    echo "Create Command Options:"
    echo "  --vhd-path PATH           - [mandatory] VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    local default_size="${DEFAULT_VHD_SIZE:-1G}"
    echo "  --size SIZE              - [optional] VHD size (e.g., 1G, 500M, 10G) [default: $default_size]"
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    echo "  --format TYPE            - [optional] Format VHD with filesystem after creation (ext4, ext3, xfs, etc.)"
    echo "  --force                  - [optional] Overwrite existing VHD (auto-unmounts if attached, prompts for confirmation)"
    echo "  Note: Without --format, creates VHD file only. With --format, also attaches and formats the disk."
    echo
    echo "Delete Command Options:"
    echo "  --vhd-path PATH           - [mandatory] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path)"
    echo "  --force                  - [optional] Skip confirmation prompt"
    echo "  Note: VHD must be unmounted and detached before deletion."
    echo
    echo "Resize Command Options:"
    echo "  --mount-point PATH       - [mandatory] Target disk mount point"
    echo "  --size SIZE              - [mandatory] New disk size (e.g., 5G, 10G)"
    echo "  Note: Creates new disk, migrates data, and replaces original with backup."
    echo
    echo "History Command Options:"
    local default_limit="${DEFAULT_HISTORY_LIMIT:-10}"
    local max_limit="${MAX_HISTORY_LIMIT:-50}"
    echo "  --limit N                - [optional] Number of detach events to show [default: $default_limit, max: $max_limit]"
    echo "  --vhd-path PATH           - [optional] Show last detach event for specific VHD path"
    echo "  Note: Shows detach history with timestamps, UUIDs, and device names."
    echo
    echo "Examples:"
    echo "  $0 attach --vhd-path C:/VMs/disk.vhdx"
    echo "  $0 format --dev-name sdd --type ext4"
    echo "  $0 format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4"
    echo "  $0 mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data"
    echo "  $0 umount --vhd-path C:/VMs/disk.vhdx"
    echo "  $0 umount --mount-point /mnt/data"
    echo "  $0 umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
    echo "  $0 detach --uuid 72a3165c-f1be-4497-a1fb-2c55054ac472"
    echo "  $0 detach --dev-name sde"
    echo "  $0 detach --vhd-path C:/VMs/disk.vhdx"
    echo "  $0 status --vhd-path C:/VMs/disk.vhdx"
    echo "  $0 status --all"
    echo "  $0 create --vhd-path C:/VMs/disk.vhdx --size 5G"
    echo "  $0 create --vhd-path C:/VMs/disk.vhdx --size 5G --format ext4"
    echo "  $0 delete --vhd-path C:/VMs/disk.vhdx"
    echo "  $0 delete --vhd-path C:/VMs/disk.vhdx --force"
    echo "  $0 resize --mount-point /mnt/data --size 10G"
    echo "  $0 history"
    echo "  $0 history --limit 20"
    echo "  $0 history --vhd-path C:/VMs/disk.vhdx"
    echo "  $0 -q status --all"
    echo
    exit 0
}

# Function to show status
# Args: $1 - VHD path (Windows format)
#       $2 - VHD UUID
#       $3 - VHD name
#       $4 - Mount point path
#       $5 - Show all flag
# Returns: 0 on success, 1 on failure
show_status() {
    # Parse status command arguments
    local vhd_path=""
    local uuid=""
    local mount_point=""
    local show_all=false
    
    # If no arguments, show help
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 status [OPTIONS]"
        echo
        echo "Options:"
        echo "  --vhd-path PATH      Show status for specific VHD path (UUID auto-discovered)"
        echo "  --uuid UUID          Show status for specific UUID"
        echo "  --mount-point PATH   Show status for specific mount point (UUID auto-discovered)"
        echo "  --all                Show all attached VHDs"
        echo
        echo "Examples:"
        echo "  $0 status --all"
        echo "  $0 status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
        echo "  $0 status --vhd-path C:/VMs/disk.vhdx"
        echo "  $0 status --mount-point /mnt/data"
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                uuid="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--mount-point requires a value"
                fi
                if ! validate_mount_point "$2"; then
                    error_exit "Invalid mount point format: $2" 1 "Mount point must be an absolute path (e.g., /mnt/data)"
                fi
                mount_point="$2"
                shift 2
                ;;
            --all)
                show_all=true
                shift
                ;;
            *)
                error_exit "Unknown status option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Try to find UUID if not provided
    if [[ -z "$uuid" ]]; then
        # If path is provided, check if VHD file exists first
        if [[ -n "$vhd_path" ]]; then
            local vhd_path_wsl
            vhd_path_wsl=$(wsl_convert_path "$vhd_path")
            
            if [[ ! -e "$vhd_path_wsl" ]]; then
                local file_not_found_help="VHD file does not exist at: $vhd_path
  (WSL path: $vhd_path_wsl)

Suggestions:
  1. Check the file path is correct
  2. Create a new VHD: $0 create --vhd-path $vhd_path --size <size>
  3. See all attached VHDs: $0 status --all"
                if [[ "$QUIET" == "true" ]]; then
                    echo "not found"
                fi
                error_exit "VHD file not found" 1 "$file_not_found_help"
            fi
            
            # File exists, try to find UUID by path with multi-VHD safety
            local discovery_result
            uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
            discovery_result=$?
            
            # Handle discovery result - status command allows empty UUID (not an error)
            # but exits on multiple VHDs (ambiguous)
            if [[ $discovery_result -eq 2 ]]; then
                # Multiple VHDs detected - use helper for consistent error message
                local script_name="${0##*/}"
                local multi_vhd_help="Cannot determine UUID from path alone.
Run '$script_name status --all' to see all attached VHDs."
                if [[ "$QUIET" == "true" ]]; then
                    echo "ambiguous: multiple VHDs"
                fi
                error_exit "Multiple VHDs are attached" 1 "$multi_vhd_help"
            elif [[ -n "$uuid" ]]; then
                log_info "Found VHD UUID: $uuid"
                log_info ""
            fi
        # Try to find UUID by mount point if provided
        elif [[ -n "$mount_point" ]]; then
            uuid=$(wsl_find_uuid_by_mountpoint "$mount_point")
            if [[ -n "$uuid" ]]; then
                log_info "Found UUID by mount point: $uuid"
                log_info ""
            fi
        fi
    fi
    
    # If --all flag, show all attached VHDs
    if [[ "$show_all" == "true" ]]; then
        log_info "========================================"
        log_info "  All Attached VHD Disks"
        log_info "========================================"
        log_info "Note: VHD paths cannot be determined from UUID alone."
        log_info "      Use 'status --vhd-path <path>' to verify a specific VHD."
        log_info ""
        
        local all_uuids
        all_uuids=$(wsl_get_disk_uuids)
        
        if [[ -z "$all_uuids" ]]; then
            log_warn "No VHDs attached to WSL"
            [[ "$QUIET" == "true" ]] && echo "No attached VHDs"
        else
            while IFS= read -r uuid; do
                log_info ""
                log_info "UUID: $uuid"
                [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
                
                if wsl_is_vhd_mounted "$uuid"; then
                    log_success "Status: Attached and Mounted"
                    [[ "$QUIET" == "true" ]] && echo "$uuid: attached,mounted"
                else
                    log_warn "Status: Attached but not mounted"
                    [[ "$QUIET" == "true" ]] && echo "$uuid: attached"
                fi
                log_info "----------------------------------------"
            done <<< "$all_uuids"
        fi
        log_info "========================================"
        exit 0
    fi
    
    # If no UUID found after all lookup attempts, report error with suggestions
    if [[ -z "$uuid" ]]; then
        local suggestions=""
        if [[ -n "$mount_point" ]]; then
            suggestions="No VHD is currently mounted at: $mount_point

Suggestions:
  1. Check if the mount point exists: ls -ld $mount_point
  2. Verify VHD is mounted: mount | grep $mount_point
  3. See all attached VHDs: $0 status --all
  4. Mount the VHD first: $0 mount --vhd-path <path> --mount-point $mount_point"
        elif [[ -n "$vhd_path" ]]; then
            # Convert to WSL path to check if file exists
            local vhd_path_wsl
            vhd_path_wsl=$(wsl_convert_path "$vhd_path")
            
            if [[ ! -e "$vhd_path_wsl" ]]; then
                suggestions="VHD file not found at: $vhd_path

Suggestions:
  1. Check the file path is correct
  2. Create a new VHD: $0 create --vhd-path $vhd_path"
            else
                suggestions="VHD file exists at: $vhd_path
But it is not currently attached to WSL.

Suggestions:
  1. Mount the VHD: $0 mount --vhd-path $vhd_path
  2. See all attached VHDs: $0 status --all"
            fi
        else
            suggestions="No UUID, path, or mount point specified.

Suggestions:
  1. Provide a UUID: $0 status --uuid <uuid>
  2. Provide a path: $0 status --vhd-path <path>
  3. Provide a mount point: $0 status --mount-point <path>
  4. See all attached VHDs: $0 status --all"
        fi
        
        if [[ "$QUIET" == "true" ]]; then
            echo "not found"
        fi
        error_exit "Unable to find VHD" 1 "$suggestions"
    fi
    
    # Show status for specific VHD
    log_info "========================================"
    log_info "  VHD Disk Status"
    log_info "========================================"
    if [[ -n "$vhd_path" ]]; then
        log_info "  Path: $vhd_path"
    else
        log_info "  Path: Unknown (use --vhd-path to query by path)"
    fi
    [[ -n "$uuid" ]] && log_info "  UUID: $uuid"
    [[ -n "$mount_point" ]] && log_info "  Mount Point: $mount_point"
    log_info ""
    
    if wsl_is_vhd_attached "$uuid"; then
        log_success "VHD is attached to WSL"
        log_info ""
        [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
        log_info ""
        
        if wsl_is_vhd_mounted "$uuid"; then
            log_success "VHD is mounted"
            [[ "$QUIET" == "true" ]] && echo "$vhd_path ($uuid): attached,mounted"
        else
            log_warn "VHD is attached but not mounted"
            [[ "$QUIET" == "true" ]] && echo "$vhd_path ($uuid): attached"
        fi
    else
        log_error "VHD not found"
        log_info "The VHD with UUID $uuid is not currently in WSL."
        [[ "$QUIET" == "true" ]] && echo "$vhd_path ($uuid): not found"
    fi
    log_info "========================================"
}

# Function to mount VHD
# 
# This function orchestrates the complete mount workflow: attachment (if needed), UUID discovery,
# and filesystem mounting. It handles three distinct scenarios based on user input.
#
# Args: $@ - Command-line arguments:
#         --mount-point PATH  Mount point (Linux absolute path, e.g., /mnt/data) [REQUIRED]
#         --vhd-path PATH     VHD path (Windows format, e.g., C:/VMs/disk.vhdx)
#         --dev-name NAME     Device name (e.g., sde) - alternative to --vhd-path
#
# Logic Flow:
# ===========
# 1. Three Mount Scenarios:
#
#    SCENARIO 1: --vhd-path provided, disk NOT attached
#    ---------------------------------------------------
#    - Takes snapshot of current block devices before attach
#    - Attempts to attach VHD using wsl.exe --mount --bare
#    - On success:
#      * Detects new device using snapshot-based comparison (detect_new_device_after_attach)
#        - Works for both formatted and unformatted VHDs
#        - Filters old devices before sleep (only sd[d-z] pattern)
#        - Excludes system disks (sda, sdb, sdc)
#      * Gets UUID from device if available (wsl_get_uuid_by_device)
#        - UUID will be empty if VHD is unformatted
#      * Validates VHD is formatted (has filesystem UUID) - errors if not
#    - Mounts filesystem using UUID (wsl_mount_vhd)
#
#    SCENARIO 2: --dev-name provided
#    --------------------------------
#    - Validates device exists in system (using lsblk)
#    - Gets UUID from device name (wsl_get_uuid_by_device)
#    - Validates device has filesystem (is formatted)
#    - Uses provided device name directly (no attachment needed)
#    - Mounts filesystem using UUID (wsl_mount_vhd)
#
#    SCENARIO 3: --vhd-path provided, disk ALREADY attached
#    -------------------------------------------------------
#    - wsl.exe attach fails with "already attached" error
#    - Uses safe UUID discovery (wsl_find_uuid_by_path) with multi-VHD safety
#    - Handles discovery errors consistently (handle_uuid_discovery_result)
#    - Gets device name from UUID using lsblk/jq lookup
#    - Mounts filesystem using UUID (wsl_mount_vhd)
#
# 3. Common Mount Logic (applies to all scenarios)
#    ----------------------------------------------
#    - Checks if VHD is already mounted at target mount point (idempotent check)
#    - If already mounted at target: exits successfully (no-op)
#    - If mounted elsewhere: warns and proceeds to mount at new location
#    - Creates mount point directory if it doesn't exist
#    - Mounts filesystem using UUID (wsl_mount_vhd)
#    - Updates tracking file with mount point and device name (if vhd_path provided)
mount_vhd() {
    # Parse mount command arguments
    local vhd_path=""
    local mount_point=""
    local dev_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--mount-point requires a value"
                fi
                if ! validate_mount_point "$2"; then
                    error_exit "Invalid mount point format: $2" 1 "Mount point must be an absolute path (e.g., /mnt/data)"
                fi
                mount_point="$2"
                shift 2
                ;;
            --dev-name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--dev-name requires a value"
                fi
                if ! validate_device_name "$2"; then
                    error_exit "Invalid device name format: $2" 1 "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde)"
                fi
                dev_name="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown mount option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$mount_point" ]]; then
        error_exit "--mount-point parameter is required" 1 "Usage: $0 mount --mount-point MOUNT_POINT [--vhd-path PATH | --dev-name DEVICE]"
    fi
    
    if [[ -z "$vhd_path" ]] && [[ -z "$dev_name" ]]; then
        error_exit "Either --vhd-path or --dev-name must be provided" 1 "Usage: $0 mount --mount-point MOUNT_POINT [--vhd-path PATH | --dev-name DEVICE]"
    fi
    
    if [[ -n "$vhd_path" ]] && [[ -n "$dev_name" ]]; then
        error_exit "Cannot specify both --vhd-path and --dev-name" 1 "Usage: $0 mount --mount-point MOUNT_POINT [--vhd-path PATH | --dev-name DEVICE]"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Mount Operation"
    log_info "========================================"
    log_info ""
    
    local uuid=""
    local found_path=""  # Path found in tracking file when vhd_path not provided
    
    # ========================================================================
    # SCENARIO 2: --dev-name provided (device already attached)
    # ========================================================================
    # User provides device name directly (e.g., "sde")
    # - No attachment needed (device already exists in system)
    # - Validate device exists, get UUID, verify it's formatted
    # ========================================================================
    if [[ -n "$dev_name" ]]; then
        log_info "Using device name: $dev_name"
        
        # Validate device exists in system (regardless of formatting)
        if ! wsl_device_exists "$dev_name"; then
            error_exit "Device $dev_name does not exist" 1 "Use 'lsblk' or '$0 status --all' to see available devices"
        fi
        
        # Get UUID from device name (requires device to be formatted)
        uuid=$(wsl_get_uuid_by_device "$dev_name")
        if [[ -z "$uuid" ]]; then
            error_exit "Device $dev_name exists but has no filesystem UUID" 1 "The device may not be formatted. Use '$0 format --dev-name $dev_name --type ext4' to format it."
        fi
        
        log_success "Found UUID: $uuid for device: $dev_name"
        
        # If vhd_path is not provided, check if UUID exists in tracking file
        # If found, update the tracking file entry with the device name
        # Store found_path for later use in common mount logic
        if [[ -z "$vhd_path" ]]; then
            if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                # Find VHD path associated with this UUID
                found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
                
                if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                    # UUID exists in tracking file - update entry with device name
                    log_debug "UUID $uuid found in tracking file for path: $found_path"
                    log_debug "Updating tracking file with device name: $dev_name"
                    
                    # Get current mount points for this path
                    local current_mount_points
                    current_mount_points=$(jq -r --arg path "$found_path" '.mappings[$path].mount_points // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
                    log_debug "Current mount points for $found_path: '$current_mount_points'"
                    
                    # Update tracking file with device name using tracking_file_save_mapping
                    # This preserves existing mount points and updates the name field
                    if tracking_file_save_mapping "$found_path" "$uuid" "$current_mount_points" "$dev_name"; then
                        log_debug "Updated tracking file: $found_path → UUID: $uuid, Device: $dev_name"
                        
                        # Clean up detach history for this path since disk is attached
                        tracking_file_remove_detach_history "$found_path"
                    else
                        log_debug "Failed to update tracking file with device name"
                    fi
                else
                    log_debug "UUID $uuid not found in tracking file - skipping update"
                fi
            fi
        fi
    
    # ========================================================================
    # SCENARIO 1 or 3: --vhd-path provided
    # ========================================================================
    # User provides VHD file path
    # - Need to determine if VHD is already attached or needs attachment
    # - Use snapshot-based detection for new attachments
    # - Use tracking file lookup for already-attached VHDs
    # ========================================================================
    elif [[ -n "$vhd_path" ]]; then
        # Validate VHD file exists before attempting any operations
        local vhd_path_wsl
        vhd_path_wsl=$(wsl_convert_path "$vhd_path")
        if [[ ! -e "$vhd_path_wsl" ]]; then
            error_exit "VHD file does not exist at $vhd_path"
        fi
        
        # Take snapshot BEFORE attach attempt for deterministic device detection
        # This allows us to identify which device was added by comparing before/after
        # Only need block devices snapshot (device-first detection, then UUID from device)
        local old_devs=($(wsl_get_block_devices))
        
        # Attempt attachment - capture both exit code and error output
        # Error output is needed to detect "already attached" scenario
        local attach_output=""
        wsl_attach_vhd "$vhd_path" "attach_output"
        local attach_result=$?
        
        if [[ $attach_result -eq 0 ]]; then
            # ================================================================
            # SCENARIO 1: Successfully attached (disk was NOT attached)
            # ================================================================
            # VHD was successfully attached - use snapshot-based device detection
            # Device-first approach works for both formatted and unformatted VHDs
            # UUID is then derived from the device if available
            # ================================================================
            log_success "VHD attached successfully"
            
            # Register for cleanup in case script fails/interrupts before mount completes
            # Will be unregistered on successful mount completion
            register_vhd_cleanup "$vhd_path" "" ""
            
            # Detect new device using snapshot-based detection
            # This works for both formatted and unformatted VHDs
            # Pass array elements directly to avoid indirect reference issues
            dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
            
            if [[ -z "$dev_name" ]]; then
                error_exit "Failed to detect device of attached VHD"
            fi
            
            # Get UUID from device (will be empty if VHD is unformatted)
            uuid=$(wsl_get_uuid_by_device "$dev_name")
            
            # Validate VHD has filesystem (is formatted)
            if [[ -z "$uuid" ]]; then
                # Provide helpful error message with format command
                local format_help="The VHD is attached but not formatted.
  Device: /dev/$dev_name

To format the VHD, run:
  $0 format --dev-name $dev_name --type ext4

Or use a different filesystem type (ext3, xfs, etc.):
  $0 format --dev-name $dev_name --type xfs"
                error_exit "VHD has no filesystem" 1 "$format_help"
            fi
            
            # Update cleanup registration with detected UUID and device name
            # This allows cleanup to use UUID for more reliable detach if needed
            if [[ -n "$uuid" ]]; then
                unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
                register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"
            fi
            
            log_info "  Detected UUID: $uuid"
            [[ -n "$dev_name" ]] && log_info "  Detected Device: /dev/$dev_name"
            
            # Clean up detach history for this path since disk is now attached
            tracking_file_remove_detach_history "$vhd_path"
            
        elif [[ "$attach_output" == *"WSL_E_USER_VHD_ALREADY_ATTACHED"* ]] || [[ "$attach_output" == *"already attached"* ]] || [[ "$attach_output" == *"already mounted"* ]]; then
            # ================================================================
            # SCENARIO 3: VHD already attached
            # ================================================================
            # Attachment failed because VHD is already attached
            # Use tracking file lookup (fast) or device scanning (with multi-VHD safety)
            # ================================================================
            log_warn "VHD is already attached, searching for UUID..."
            
            # Use safe UUID discovery with multi-VHD detection
            # This function:
            # 1. Checks tracking file first (fastest, most reliable)
            # 2. Falls back to device scanning if needed
            # 3. Returns error code 2 if multiple VHDs found (ambiguous)
            # 4. Returns error code 1 if not found
            local discovery_result
            uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
            discovery_result=$?
            
            # Handle discovery result with consistent error messages
            # This provides user-friendly errors for multi-VHD scenarios
            handle_uuid_discovery_result "$discovery_result" "$uuid" "mount" "$vhd_path"
            
            if [[ -z "$uuid" ]]; then
                error_exit "Cannot mount VHD: UUID not found for $vhd_path" 1 "The VHD may be attached but not formatted, or there may be multiple VHDs attached. Use '$0 status --all' to see all attached VHDs."
            fi
            
            # Get device name from UUID for tracking file updates
            dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            
            # Clean up detach history for this path since disk is attached
            tracking_file_remove_detach_history "$vhd_path"
            
        else
            # Other attach error (not "already attached")
            error_exit "Failed to attach VHD: $attach_output"
        fi
    fi
    
    # ========================================================================
    # COMMON MOUNT LOGIC (applies to all scenarios)
    # ========================================================================
    # At this point, we have:
    # - uuid: The UUID of the VHD to mount
    # - dev_name: The device name (if available)
    # - mount_point: The target mount point (validated)
    # ========================================================================
    
    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
    log_info ""
    
    # Check if VHD is already mounted at the target mount point (idempotent operation)
    # This allows safe re-running of mount command
    local current_mount_point
    current_mount_point=$(wsl_get_vhd_mount_point "$uuid")
    
    if [[ -n "$current_mount_point" ]] && [[ "$current_mount_point" == "$mount_point" ]]; then
        # Already mounted at target location - nothing to do
        log_success "VHD is already mounted at $mount_point"
        log_info "Nothing to do."
        
        # Still update tracking file with mount point (in case it's not recorded)
        # This ensures the tracking file stays in sync with actual mount state
        tracking_file_update_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" "$found_path"
        
        # Unregister from cleanup tracking (operation complete, no cleanup needed)
        if [[ -n "$vhd_path" ]]; then
            unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
        fi
    else
        # Need to mount (either not mounted, or mounted at different location)
        if [[ -n "$current_mount_point" ]]; then
            log_warn "VHD is mounted at a different location: $current_mount_point"
            log_info "Mounting to requested location: $mount_point"
        else
            log_warn "VHD is attached but not mounted"
        fi
        
        # Create mount point directory if it doesn't exist
        # Uses secure directory creation with proper permissions
        if [[ ! -d "$mount_point" ]]; then
            log_info "Creating mount point: $mount_point"
            if ! create_mount_point "$mount_point"; then
                error_exit "Failed to create mount point"
            fi
        fi
        
        # Perform the actual mount operation using UUID
        # UUID-based mounting is more reliable than device names (device names can change)
        log_info "Mounting VHD to $mount_point..."
        if wsl_mount_vhd "$uuid" "$mount_point"; then
            log_success "VHD mounted successfully"
            
            # Update tracking file with mount point and device name
            # This enables future path-based operations without requiring UUID
            tracking_file_update_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" "$found_path"
            
            # Save device name to tracking file if we detected it and it's not already stored
            # Device name is useful for user reference and format operations
            if [[ -n "$vhd_path" ]] && [[ -n "$dev_name" ]]; then
                local normalized_path=$(normalize_vhd_path "$vhd_path")
                if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                    local current_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
                    # Only update if dev_name field is empty (preserve existing device names)
                    if [[ -z "$current_dev_name" || "$current_dev_name" == "null" ]]; then
                        # Save mapping with device name for future reference
                        tracking_file_save_mapping "$vhd_path" "$uuid" "$mount_point" "$dev_name"
                    fi
                fi
            fi
            
            # Unregister from cleanup tracking - operation completed successfully
            # VHD is now mounted and should remain attached even if script exits
            if [[ -n "$vhd_path" ]]; then
                unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
            fi
        else
            error_exit "Failed to mount VHD"
        fi
    fi

    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Mount operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if wsl_is_vhd_mounted "$uuid"; then
            if [[ -n "$vhd_path" ]]; then
                echo "$vhd_path ($uuid): attached,mounted"
            else
                echo "$dev_name ($uuid): mounted"
            fi
        else
            if [[ -n "$vhd_path" ]]; then
                echo "$vhd_path ($uuid): mount failed"
            else
                echo "$dev_name ($uuid): mount failed"
            fi
        fi
    fi
}

# Function to unmount VHD
# Arguments:
#   --vhd-path PATH       VHD file path (Windows format, optional, auto-discovered if not provided)
#   --dev-name DEVICE     Device name (e.g., sde)
#   --mount-point PATH    Mount point (Linux absolute path, e.g., /mnt/data)
#
# Logic Flow:
# ===========
# 1. Three Unmount Scenarios:
#
#    SCENARIO 1: --vhd-path provided
#    ---------------------------------------------------
#    - Validates VHD file exists (validate_windows_path)
#    - Validates VHD is attached to WSL (wsl_is_vhd_attached)
#    - Validates VHD is mounted to filesystem (wsl_is_vhd_mounted)
#    - Unmounts filesystem from mount point (wsl_umount_vhd)
#    - Clears mount point in tracking file (tracking_file_remove_mount_point)
#    - Detaches from WSL (wsl_detach_vhd)
#    - Saves detach event to history
#    - Keeps mapping in tracking file (for future re-attachment)
#
#    SCENARIO 2: --dev-name provided
#    ---------------------------------------------------
#    - Validates device exists in system (wsl_device_exists)
#    - Gets UUID from device name (wsl_get_uuid_by_device)
#    - Validates VHD is attached to WSL (wsl_is_vhd_attached)
#    - Validates VHD is mounted to filesystem (wsl_is_vhd_mounted)
#    - Unmounts filesystem from mount point (wsl_umount_vhd)
#    - Clears mount point in tracking file (tracking_file_remove_mount_point)
#    - Detaches from WSL (wsl_detach_vhd) if --vhd-path provided
#    - Saves detach event to history
#    - Keeps mapping in tracking file (for future re-attachment)
#
#    SCENARIO 3: --mount-point provided
#    ---------------------------------------------------
#    - Discovers UUID from mount point (wsl_find_uuid_by_mountpoint)
#    - Validates VHD is attached to WSL (wsl_is_vhd_attached)
#    - Validates VHD is mounted to filesystem (wsl_is_vhd_mounted)
#    - Unmounts filesystem from mount point (wsl_umount_vhd)
#    - Clears mount point in tracking file (tracking_file_remove_mount_point)
umount_vhd() {
    # Parse umount command arguments
    local vhd_path=""
    local uuid=""
    local mount_point=""
    local dev_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            --dev-name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--dev-name requires a value"
                fi
                if ! validate_device_name "$2"; then
                    error_exit "Invalid device name format: $2" 1 "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde)"
                fi
                dev_name="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--mount-point requires a value"
                fi
                if ! validate_mount_point "$2"; then
                    error_exit "Invalid mount point format: $2" 1 "Mount point must be an absolute path (e.g., /mnt/data)"
                fi
                mount_point="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown umount option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # ========================================================================
    # SCENARIO 1: --dev-name provided
    # ========================================================================
    # Get UUID from device name
    # ========================================================================
    if [[ -n "$dev_name" ]]; then
        log_info "Using device name: $dev_name"
        
        # Validate device exists in system
        if ! wsl_device_exists "$dev_name"; then
            error_exit "Device $dev_name does not exist" 1 "Use 'lsblk' or '$0 status --all' to see available devices"
        fi
        
        # Get UUID from device name (requires device to be formatted)
        uuid=$(wsl_get_uuid_by_device "$dev_name")
        if [[ -z "$uuid" ]]; then
            error_exit "Device $dev_name exists but has no filesystem UUID" 1 "The device may not be formatted. Use '$0 format --dev-name $dev_name --type ext4' to format it."
        fi
        
        log_success "Found UUID: $uuid for device: $dev_name"
        log_info ""
    
    # ========================================================================
    # SCENARIO 2: --vhd-path provided
    # ========================================================================
    # Try to find UUID by path with multi-VHD safety
    # ========================================================================
    elif [[ -n "$vhd_path" ]]; then
        # Try to find UUID by path with multi-VHD safety
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        # Handle discovery result with consistent error handling
        handle_uuid_discovery_result "$discovery_result" "$uuid" "umount" "$vhd_path"
        log_info ""
    
    # ========================================================================
    # SCENARIO 3: --mount-point provided
    # ========================================================================
    # Try to find UUID by mount point
    # ========================================================================
    elif [[ -n "$mount_point" ]]; then
        # Try to find UUID by mount point
        uuid=$(wsl_find_uuid_by_mountpoint "$mount_point")
        if [[ -n "$uuid" ]]; then
            log_info "Discovered UUID from mount point: $uuid"
            log_info ""
        fi
    fi
    
    # If UUID still not found, report error
    if [[ -z "$uuid" ]]; then
        local uuid_help="Could not discover UUID. Please provide one of:
  --dev-name DEVICE     Explicit device name (e.g., sde)
  --vhd-path PATH       VHD file path (will attempt discovery)
  --mount-point PATH    Mount point (will attempt discovery)

To find device name or UUID, run: $0 status --all"
        if [[ "$QUIET" == "true" ]]; then
            echo "uuid not found"
        fi
        error_exit "Unable to identify VHD" 1 "$uuid_help"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Unmount Operation"
    log_info "========================================"
    log_info ""
    
    if ! wsl_is_vhd_attached "$uuid"; then
        log_warn "VHD is not attached to WSL"
        log_info "Nothing to do."
        log_info "========================================"
        exit 0
    fi
    
    log_info "VHD is attached to WSL"
    log_info ""
    
    # First, unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$uuid"; then
        # Discover mount point if not provided
        if [[ -z "$mount_point" ]]; then
            mount_point=$(wsl_get_vhd_mount_point "$uuid")
        fi
        
        log_info "Unmounting VHD from $mount_point..."
        if wsl_umount_vhd "$mount_point"; then
            log_success "VHD unmounted successfully"
            
            # Clear mount point in tracking file using the new helper function
            # This works with UUID, mount point, vhd_path, or dev_name
            tracking_file_remove_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" ""
        else
            error_exit "Failed to unmount VHD"
        fi
    else
        log_warn "VHD is not mounted to filesystem"
    fi
    
    # Then, detach from WSL (only if path was provided)
    if [[ -n "$vhd_path" ]]; then
        log_info "Detaching VHD from WSL..."
        # Get device name from tracking file for history
        local dev_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$vhd_path")
            dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        if wsl_detach_vhd "$vhd_path" "$uuid" "$dev_name"; then
            log_success "VHD detached successfully"
            # Save to detach history and remove from active mappings
            tracking_file_save_detach_history "$vhd_path" "$uuid" "$dev_name"
            tracking_file_remove_mapping "$vhd_path"
        else
            error_exit "Failed to detach VHD from WSL"
        fi
    else
        log_warn "VHD was not detached from WSL"
        log_info "The VHD path is required to detach from WSL."
        log_info ""
        log_info "To fully detach the VHD, run:"
        log_info "  $0 detach --vhd-path <VHD_PATH>"
    fi

    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Unmount operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if ! wsl_is_vhd_attached "$uuid"; then
            echo "$vhd_path ($uuid): detached"
        elif [[ -z "$vhd_path" ]]; then
            echo "($uuid): unmounted,attached"
        else
            echo "$vhd_path ($uuid): umount failed"
        fi
    fi
}

# Function to detach VHD
# Arguments:
#   --dev-name DEVICE     Device name (e.g., sde) - alternative to --uuid or --vhd-path
#   --uuid UUID           VHD UUID - alternative to --dev-name or --vhd-path
#   --vhd-path PATH       VHD file path (Windows format) - alternative to --dev-name or --uuid
#
# Logic Flow:
# ===========
# 1. Three Detach Scenarios:
#
#    SCENARIO 1: --dev-name provided
#    ---------------------------------------------------
#    - Validates device exists in system (wsl_device_exists)
#    - Gets UUID from device name (wsl_get_uuid_by_device)
#    - Validates device has filesystem UUID (is formatted)
#    - Validates VHD is attached to WSL (wsl_is_vhd_attached)
#    - Looks up VHD path from tracking file using UUID (JQ_GET_PATH_BY_UUID)
#    - Unmounts filesystem from mount point if mounted (wsl_umount_vhd)
#    - Clears mount points in tracking file (remove_tracking_file_mount_point)
#    - Detaches from WSL (wsl_detach_vhd)
#    - Saves detach event to history
#    - Keeps mapping in tracking file (for future re-attachment)
#
#    SCENARIO 2: --uuid provided
#    ---------------------------------------------------
#    - Gets device name from UUID using lsblk (JQ_GET_DEVICE_NAME_BY_UUID)
#    - Validates VHD is attached to WSL (wsl_is_vhd_attached)
#    - Looks up VHD path from tracking file using UUID (JQ_GET_PATH_BY_UUID)
#    - Unmounts filesystem from mount point if mounted (wsl_umount_vhd)
#    - Clears mount points in tracking file (remove_tracking_file_mount_point)
#    - Detaches from WSL (wsl_detach_vhd)
#    - Saves detach event to history
#    - Keeps mapping in tracking file (for future re-attachment)
#
#    SCENARIO 3: --vhd-path provided
#    ---------------------------------------------------
#    - Discovers UUID from path using wsl_find_uuid_by_path (with multi-VHD safety)
#    - Handles discovery errors consistently (handle_uuid_discovery_result)
#    - Gets device name from UUID using lsblk (JQ_GET_DEVICE_NAME_BY_UUID)
#    - Validates VHD is attached to WSL (wsl_is_vhd_attached)
#    - Unmounts filesystem from mount point if mounted (wsl_umount_vhd)
#    - Clears mount points in tracking file (remove_tracking_file_mount_point)
#    - Detaches from WSL (wsl_detach_vhd)
#    - Saves detach event to history
#    - Keeps mapping in tracking file (for future re-attachment)
#
# Common Logic (all scenarios):
#    - If --vhd-path is explicitly provided, it takes precedence over tracking file lookup
#    - Path lookup from tracking file enables mount point clearing and history tracking
#    - If path cannot be found in tracking file, user must provide it explicitly
#
# Note: Unlike delete_vhd(), this function does NOT remove the mapping from
#       the tracking file. The mapping is preserved so the VHD can be easily
#       re-attached later. Only delete_vhd() removes mappings entirely.
detach_vhd() {
    # Parse detach command arguments
    local uuid=""
    local vhd_path=""
    local dev_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dev-name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--dev-name requires a value"
                fi
                if ! validate_device_name "$2"; then
                    error_exit "Invalid device name format: $2" 1 "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde)"
                fi
                dev_name="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                uuid="$2"
                shift 2
                ;;
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown detach option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate that at least one identifier is provided (mutually exclusive)
    if [[ -z "$uuid" ]] && [[ -z "$dev_name" ]] && [[ -z "$vhd_path" ]]; then
        error_exit "Either --dev-name, --uuid, or --vhd-path must be provided" 1 "Usage: $0 detach [--dev-name DEVICE | --uuid UUID | --vhd-path PATH]"
    fi
    
    # Validate mutually exclusive options
    local identifier_count=0
    [[ -n "$uuid" ]] && ((identifier_count++))
    [[ -n "$dev_name" ]] && ((identifier_count++))
    [[ -n "$vhd_path" ]] && ((identifier_count++))
    
    if [[ $identifier_count -gt 1 ]]; then
        error_exit "Cannot specify multiple identifiers. Use only one of: --dev-name, --uuid, or --vhd-path" 1 "Usage: $0 detach [--dev-name DEVICE | --uuid UUID | --vhd-path PATH]"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Detach Operation"
    log_info "========================================"
    log_info ""
    
    # ========================================================================
    # SCENARIO 1: --dev-name provided
    # ========================================================================
    # Get UUID from device name, then look up path from tracking file
    # ========================================================================
    if [[ -n "$dev_name" ]]; then
        log_info "Using device name: $dev_name"
        
        # Validate device exists in system
        if ! wsl_device_exists "$dev_name"; then
            error_exit "Device $dev_name does not exist" 1 "Use 'lsblk' or '$0 status --all' to see available devices"
        fi
        
        # Get UUID from device name (requires device to be formatted)
        uuid=$(wsl_get_uuid_by_device "$dev_name")
        if [[ -z "$uuid" ]]; then
            error_exit "Device $dev_name exists but has no filesystem UUID" 1 "The device may not be formatted. Use '$0 format --dev-name $dev_name --type ext4' to format it."
        fi
        
        log_success "Found UUID: $uuid for device: $dev_name"
        log_info ""
    
    # ========================================================================
    # SCENARIO 2: --uuid provided
    # ========================================================================
    # Get device name from UUID, then look up path from tracking file
    # ========================================================================
    elif [[ -n "$uuid" ]]; then
        log_info "Using UUID: $uuid"
        
        # Get device name from UUID for display
        if [[ "$DEBUG" == "true" ]]; then
            log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
        fi
        dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        if [[ -n "$dev_name" ]]; then
            log_info "Device: /dev/$dev_name"
        fi
        log_info ""
    
    # ========================================================================
    # SCENARIO 3: --vhd-path provided
    # ========================================================================
    # Try to discover UUID from tracking file or device detection
    # If UUID can't be discovered (e.g., multiple VHDs), proceed anyway
    # since wsl.exe --unmount works directly with the path
    # ========================================================================
    elif [[ -n "$vhd_path" ]]; then
        log_info "Using VHD path: $vhd_path"
        
        # Try to find UUID by path with multi-VHD safety
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 0 && -n "$uuid" ]]; then
            # UUID found successfully
            log_info "Discovered UUID: $uuid"
            
            # Get device name from UUID for display
            dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            if [[ -n "$dev_name" ]]; then
                log_info "Device: /dev/$dev_name"
            fi
        elif [[ $discovery_result -eq 2 ]]; then
            # Multiple VHDs attached - can't discover UUID, but can still detach by path
            log_warn "Multiple VHDs attached - cannot verify mount status"
            log_info "Proceeding with path-based detach..."
            uuid=""  # Clear - will skip mount check
        else
            # UUID not found - VHD may not be attached
            log_warn "Could not discover UUID - VHD may not be attached"
            uuid=""
        fi
        log_info ""
    fi
    
    # Check if VHD is attached (only if we have UUID)
    # When UUID is unknown but path is provided, skip this check and try detach directly
    if [[ -n "$uuid" ]]; then
        if ! wsl_is_vhd_attached "$uuid"; then
            log_warn "VHD is not attached to WSL"
            log_info "Nothing to do."
            [[ "$QUIET" == "true" ]] && echo "${uuid:-$dev_name}: not attached"
            log_info "========================================"
            exit 0
        fi
        
        log_info "VHD is attached to WSL"
        log_info "  UUID: $uuid"
        [[ -n "$dev_name" ]] && log_info "  Device: /dev/$dev_name"
        log_info ""
        
        # Look up VHD path from tracking file using UUID
        # This enables path-based operations (mount point clearing, history tracking)
        if [[ -z "$vhd_path" ]]; then
            if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                # Look up path from tracking file using UUID
                local found_path
                found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
                
                if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                    vhd_path="$found_path"
                    log_debug "Found VHD path in tracking file: $vhd_path"
                else
                    log_debug "UUID $uuid not found in tracking file"
                fi
            fi
        fi
        
        # Show current VHD info
        [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
        log_info ""
        
        # Check if mounted and unmount first
        if wsl_is_vhd_mounted "$uuid"; then
            local mount_point=$(wsl_get_vhd_mount_point "$uuid")
            log_info "VHD is mounted at: $mount_point"
            log_info "Unmounting VHD first..."
            
            if wsl_umount_vhd "$mount_point"; then
                log_success "VHD unmounted successfully"
                
                # Clear mount point in tracking file using the new helper function
                # This works with UUID, mount point, vhd_path, or dev_name
                tracking_file_remove_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" ""
            else
                error_exit "Failed to unmount VHD"
            fi
            log_info ""
        else
            log_info "VHD is not mounted to filesystem"
            log_info ""
        fi
    else
        # UUID unknown - proceeding with path-based detach only
        # Cannot check mount status, wsl.exe will fail if still mounted
        log_info "Attempting path-based detach (mount status unknown)..."
        log_info ""
    fi
    
    # Detach from WSL
    log_info "Detaching VHD from WSL..."
    
    if [[ -n "$vhd_path" ]]; then
        # Get VHD name from tracking file for history
        local dev_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$vhd_path")
            dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        
        # Use path if we have it, pass UUID and dev_name for history tracking
        if wsl_detach_vhd "$vhd_path" "$uuid" "$dev_name"; then
            log_success "VHD detached successfully"
            
            # Save to detach history and remove from active mappings
            tracking_file_save_detach_history "$vhd_path" "$uuid" "$dev_name"
            tracking_file_remove_mapping "$vhd_path"
        else
            error_exit "Failed to detach VHD from WSL"
        fi
    else
        # If we couldn't find the path, report error with helpful message
        local identifier="${dev_name:-$uuid}"
        local path_help="The VHD path could not be found automatically.
The VHD may not be in the tracking file, or it may have been attached outside this tool.

Please provide the path explicitly:
  $0 detach --dev-name $identifier --vhd-path <vhd_path>
  $0 detach --uuid $identifier --vhd-path <vhd_path>

Or use the umount command if you know the path or mount point:
  $0 umount --vhd-path <vhd_path>
  $0 umount --mount-point <mount_point>"
        error_exit "Could not determine VHD path" 1 "$path_help"
    fi
    
    log_info ""
    log_info "========================================"
    log_info "  Detach operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        local identifier="${dev_name:-$uuid}"
        if ! wsl_is_vhd_attached "$uuid"; then
            echo "$identifier: detached"
        else
            echo "$identifier: detach failed"
        fi
    fi
}

# Function to delete VHD
# Arguments:
#   --vhd-path PATH       VHD file path (Windows format, optional, auto-discovered if not provided)
#   --uuid UUID           VHD UUID (optional, auto-discovered if not provided)
#   --force               Force deletion without confirmation
#
# Logic Flow:
# ===========
# 1. Validate required parameters
# 2. Convert Windows path to WSL path to check if VHD exists
# 3. Try to discover UUID if not provided
# 4. Check if VHD is currently attached
# 5. Attempt to detach if attached
# 6. Delete the VHD file
# 7. Remove mapping from tracking file
# 8. Report success or error
#
# Note: Unlike detach_vhd(), this function does NOT remove the mapping from
#       the tracking file. The mapping is preserved so the VHD can be easily
#       re-attached later. Only delete_vhd() removes mappings entirely.
delete_vhd() {
    # Parse delete command arguments
    local vhd_path=""
    local uuid=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                uuid="$2"
                shift 2
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                error_exit "Unknown delete option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate that at least vhd-path is provided
    if [[ -z "$vhd_path" && -z "$uuid" ]]; then
        error_exit "Either --vhd-path or --uuid is required" 1 "Usage: $0 delete [--vhd-path PATH | --uuid UUID] [--force]"
    fi
    
    if [[ -z "$vhd_path" ]]; then
        error_exit "VHD path is required" 1 "Use --vhd-path to specify the VHD file path"
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path")
    if [[ ! -e "$vhd_path_wsl" ]]; then
        error_exit "VHD file does not exist at $vhd_path (WSL path: $vhd_path_wsl)"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Deletion"
    log_info "========================================"
    log_info ""
    
    # Try to discover UUID if not provided
    if [[ -z "$uuid" ]]; then
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 2 ]]; then
            # Multiple VHDs detected - not a blocker for delete, just can't verify attachment
            log_warn "Multiple VHDs attached - cannot verify if this VHD is attached"
            log_info "Proceeding with caution..."
            log_info ""
            uuid=""  # Clear to skip attachment check
        elif [[ -n "$uuid" ]]; then
            log_info "Discovered UUID from path: $uuid"
            log_info ""
        fi
    fi
    
    # Check if VHD is currently attached
    if [[ -n "$uuid" ]] && wsl_is_vhd_attached "$uuid"; then
        # Try to automatically detach before failing
        log_warn "VHD is currently attached to WSL"
        log_info "Attempting to detach automatically..."
        
        # Try umount first (handles both unmount and detach)
        if [[ -n "$vhd_path" ]]; then
            if bash "$0" -q umount --vhd-path "$vhd_path" >/dev/null 2>&1; then
                log_success "VHD detached successfully"
                # Wait a moment for detachment to complete
                sleep 1
            else
                # Umount failed, try direct wsl.exe --unmount as fallback
                if wsl.exe --unmount "$vhd_path" >/dev/null 2>&1; then
                    log_success "VHD detached successfully"
                    sleep 1
                else
                    local detach_help="The VHD must be unmounted and detached before deletion.
To unmount and detach, run:
  $0 umount --vhd-path $vhd_path

Then try the delete command again."
                    error_exit "VHD is currently attached to WSL and could not be detached" 1 "$detach_help"
                fi
            fi
        else
            local detach_help="The VHD must be unmounted and detached before deletion.
To unmount and detach, run:
  $0 umount --uuid $uuid

Then try the delete command again."
            error_exit "VHD is currently attached to WSL" 1 "$detach_help"
        fi
    fi
    
    log_info "VHD file: $vhd_path"
    log_info "  (WSL path: $vhd_path_wsl)"
    log_info ""
    
    # Confirmation prompt unless --force is used or YES flag is set
    if [[ "$force" == "false" ]] && [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
        log_warn "WARNING: This operation cannot be undone!"
        echo -n "Are you sure you want to delete this VHD? (yes/no): "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Deletion cancelled."
            exit 0
        fi
        log_info ""
    fi
    
    # Delete the VHD file
    log_info "Deleting VHD file..."
    if wsl_delete_vhd "$vhd_path"; then
        log_success "VHD deleted successfully"
        [[ "$QUIET" == "true" ]] && echo "$vhd_path: deleted"
        
        # Remove mapping from tracking file
        tracking_file_remove_mapping "$vhd_path"
    else
        error_exit "Failed to delete VHD"
    fi
    
    log_info ""
    log_info "========================================"
    log_info "  Deletion completed"
    log_info "========================================"
    
    return 0
}

# Function to create VHD
# Arguments:
#   --vhd-path PATH       VHD file path (Windows format, required)
#   --size SIZE           VHD size (e.g., 1G, 500M, 10G) [default: 1G]
#   --force               Force creation without confirmation
#
# Logic Flow:
# ===========
# 1. Validate required parameters
# 2. Check if VHD already exists
# 3. If exists and not forced, prompt for confirmation
# 4. If exists and forced, attempt to detach and overwrite
# 5. Create the VHD file
# 6. Report success or error
#
# Note: Unlike delete_vhd(), this function does NOT remove the mapping from
#       the tracking file. The mapping is preserved so the VHD can be easily
#       re-attached later. Only delete_vhd() removes mappings entirely.
create_vhd() {
    # Parse create command arguments
    local vhd_path=""
    local default_size="${DEFAULT_VHD_SIZE:-1G}"
    local create_size="$default_size"
    local force="false"
    local format_type=""  # Optional: filesystem type to format with after creation
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            --size)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--size requires a value"
                fi
                if ! validate_size_string "$2"; then
                    error_exit "Invalid size format: $2" 1 "Size must be in format: number[K|M|G|T] (e.g., 5G, 500M)"
                fi
                create_size="$2"
                shift 2
                ;;
            --format)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--format requires a filesystem type value"
                fi
                if ! validate_filesystem_type "$2"; then
                    error_exit "Invalid filesystem type: $2" 1 "Supported types: ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat"
                fi
                format_type="$2"
                shift 2
                ;;
            --force)
                force="true"
                shift
                ;;
            *)
                error_exit "Unknown create option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$vhd_path" ]]; then
        error_exit "VHD path is required" 1 "Use --vhd-path to specify the VHD file path"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Creation"
    log_info "========================================"
    log_info ""
    
    # Check if VHD already exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path")
    if [[ -e "$vhd_path_wsl" ]]; then
        if [[ "$force" == "false" ]]; then
            local exists_help="Use 'mount' command to attach the existing VHD, or use --force to overwrite"
            error_exit "VHD file already exists at $vhd_path" 1 "$exists_help"
        else
            # Force mode: prompt for confirmation before deleting
            log_warn "VHD file already exists at $vhd_path"
            log_info ""
            
            # Check if VHD is currently attached (with multi-VHD safety)
            local existing_uuid
            local discovery_result
            existing_uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
            discovery_result=$?
            
            # If UUID discovery failed due to multiple VHDs, try tracking file directly
            if [[ $discovery_result -eq 2 ]]; then
                # Multiple VHDs attached - try tracking file lookup
                local tracked_uuid=$(tracking_file_lookup_uuid_by_path "$vhd_path")
                if [[ -n "$tracked_uuid" ]] && wsl_is_vhd_attached "$tracked_uuid"; then
                    existing_uuid="$tracked_uuid"
                    discovery_result=0
                fi
            fi
            
            # Check if VHD needs to be unmounted/detached
            # Only set needs_unmount if we confirmed the VHD is actually attached
            local needs_unmount=false
            if [[ $discovery_result -eq 0 && -n "$existing_uuid" ]] && wsl_is_vhd_attached "$existing_uuid"; then
                needs_unmount=true
            fi
            # Note: If UUID discovery failed (multiple VHDs or not found), we don't assume
            # the VHD is attached. We'll just try to delete the file - if it's locked,
            # the delete will fail with a clear error.
            
            if [[ "$needs_unmount" == "true" ]]; then
                log_warn "VHD is currently attached to WSL"
                log_info ""
                
                # Ask for permission to unmount in non-quiet mode (unless YES flag is set)
                if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
                    log_warn "The VHD must be unmounted before overwriting."
                    echo -n "Do you want to unmount it now? (yes/no): "
                    read -r unmount_confirmation
                    
                    if [[ "$unmount_confirmation" != "yes" ]]; then
                        log_info "Operation cancelled."
                        log_info ""
                        log_info "To unmount manually, run:"
                        log_info "  $0 umount --vhd-path $vhd_path"
                        exit 0
                    fi
                    log_info ""
                elif [[ "$YES" == "true" ]]; then
                    log_info "Auto-unmounting VHD (--yes flag set)..."
                    log_info ""
                fi
                
                # Perform unmount operation
                log_info "Unmounting VHD..."
                
                if [[ $discovery_result -eq 0 && -n "$existing_uuid" ]]; then
                    # We have a UUID - use normal unmount flow
                    # Check if mounted and unmount from filesystem first
                    if wsl_is_vhd_mounted "$existing_uuid"; then
                        local existing_mount_point=$(wsl_get_vhd_mount_point "$existing_uuid")
                        if [[ -n "$existing_mount_point" ]]; then
                            if wsl_umount_vhd "$existing_mount_point"; then
                                log_success "VHD unmounted from filesystem"
                            else
                                log_error "Failed to unmount VHD from filesystem"
                                log_info "Checking for processes using the mount point:"
                                # Use safe_sudo for lsof (non-critical diagnostic command)
                                if check_sudo_permissions; then
                                    safe_sudo lsof +D "$existing_mount_point" 2>/dev/null || log_info "  No processes found"
                                else
                                    log_info "  Cannot check processes (sudo permissions required)"
                                fi
                                error_exit "Failed to unmount VHD from filesystem"
                            fi
                        fi
                    fi
                    
                    # Detach from WSL
                    # Get device name from tracking file for history
                    local existing_dev_name=""
                    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                        local normalized_path=$(normalize_vhd_path "$vhd_path")
                        existing_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
                    fi
                    if wsl_detach_vhd "$vhd_path" "$existing_uuid" "$existing_dev_name"; then
                        log_success "VHD detached from WSL"
                        log_info ""
                    else
                        # Detach failed but we can still try to delete (VHD may already be detached)
                        log_warn "Could not confirm VHD detachment - continuing with deletion"
                        log_info ""
                    fi
                else
                    # Multiple VHDs or UUID not found - try direct unmount by path
                    log_info "Attempting to detach by path (UUID discovery ambiguous)..."
                    if wsl.exe --unmount "$vhd_path" 2>/dev/null; then
                        log_success "VHD detached from WSL"
                        log_info ""
                    else
                        log_warn "Could not confirm VHD detachment - continuing with deletion"
                        log_info ""
                    fi
                fi
                
                # Small delay to ensure detachment is complete
                sleep 2
            fi
            
            # Confirmation prompt in non-quiet mode (unless YES flag is set)
            if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
                log_warn "WARNING: This will permanently delete the existing VHD file!"
                echo -n "Are you sure you want to overwrite $vhd_path? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    log_info "Operation cancelled."
                    exit 0
                fi
                log_info ""
            elif [[ "$YES" == "true" ]]; then
                log_info "Auto-confirming overwrite (--yes flag set)..."
                log_info ""
            fi
            
            # Delete the existing VHD
            log_info "Deleting existing VHD file..."
            if [[ "$DEBUG" == "true" ]]; then
                log_debug "rm -f '$vhd_path_wsl'"
            fi
            if rm -f "$vhd_path_wsl"; then
                log_success "Existing VHD deleted"
                log_info ""
            else
                error_exit "Failed to delete existing VHD"
            fi
        fi
    fi
    
    log_info "Creating VHD disk..."
    log_info "  Path: $vhd_path"
    log_info "  Size: $create_size"
    log_info ""
    
    # Ensure qemu-img is installed
    if ! command -v qemu-img &> /dev/null; then
        local install_help="Please install it first:
  Arch/Manjaro: sudo pacman -Sy qemu-img
  Ubuntu/Debian: sudo apt install qemu-utils
  Fedora: sudo dnf install qemu-img"
        error_exit "qemu-img is not installed" 1 "$install_help"
    fi
    
    # Create parent directory if it doesn't exist
    local vhd_dir=$(dirname "$vhd_path_wsl")
    if [[ ! -d "$vhd_dir" ]]; then
        log_info "Creating directory: $vhd_dir"
        if ! debug_cmd mkdir -p "$vhd_dir" 2>/dev/null; then
            error_exit "Failed to create directory $vhd_dir"
        fi
    fi
    
    # Create the VHD file
    if ! debug_cmd qemu-img create -f vhdx "$vhd_path_wsl" "$create_size" >/dev/null 2>&1; then
        error_exit "Failed to create VHD file"
    fi
    
    log_success "VHD file created successfully"
    log_info ""
    
    # If --format option was provided, attach and format the VHD
    if [[ -n "$format_type" ]]; then
        log_info "========================================"
        log_info "  Formatting VHD"
        log_info "========================================"
        log_info ""
        log_info "Attaching VHD to WSL for formatting..."
        log_info ""
        
        # Take snapshot of current block devices before attaching
        local old_devs=($(wsl_get_block_devices))
        log_debug "Captured old_devs array (count: ${#old_devs[@]}): ${old_devs[*]}"
        
        # Attach the VHD
        if ! wsl_attach_vhd "$vhd_path"; then
            error_exit "Failed to attach VHD to WSL for formatting"
        fi
        
        # Register for cleanup in case script fails/interrupts before completion
        register_vhd_cleanup "$vhd_path" "" ""
        
        log_success "VHD attached to WSL"
        log_info ""
        
        # Detect new device using snapshot-based detection
        local dev_name
        dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
        
        if [[ -z "$dev_name" ]]; then
            error_exit "Failed to detect device of attached VHD"
        fi
        
        log_success "Device detected: /dev/$dev_name"
        log_info ""
        log_info "Formatting device /dev/$dev_name with $format_type..."
        log_info ""
        
        # Format the device using helper function
        local uuid
        uuid=$(format_vhd "$dev_name" "$format_type")
        if [[ $? -ne 0 || -z "$uuid" ]]; then
            error_exit "Failed to format device /dev/$dev_name with $format_type"
        fi
        
        log_success "VHD formatted successfully"
        log_info "  Device: /dev/$dev_name"
        log_info "  UUID: $uuid"
        log_info "  Filesystem: $format_type"
        log_info ""
        
        # Update cleanup registration with UUID
        unregister_vhd_cleanup "$vhd_path"
        register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"
        
        # Save mapping to tracking file
        tracking_file_save_mapping "$vhd_path" "$uuid" "" "$dev_name"
        log_debug "Saved tracking file mapping: $vhd_path → $uuid"
        
        # Detach the VHD - leave it in clean state (not attached)
        log_info "Detaching VHD..."
        if wsl_detach_vhd "$vhd_path" "$uuid" "$dev_name"; then
            log_success "VHD detached from WSL"
            # Save to detach history and remove from active mappings
            tracking_file_save_detach_history "$vhd_path" "$uuid" "$dev_name"
            tracking_file_remove_mapping "$vhd_path"
        else
            log_warn "Could not detach VHD - it may still be attached"
        fi
        log_info ""
        
        # Unregister from cleanup - operation completed successfully
        unregister_vhd_cleanup "$vhd_path"
        
        log_info "========================================"
        log_info "  Creation completed"
        log_info "========================================"
        log_info ""
        log_info "The VHD has been created and formatted."
        log_info "  Path: $vhd_path"
        log_info "  UUID: $uuid"
        log_info "  Filesystem: $format_type"
        log_info ""
        log_info "To use the VHD, run:"
        log_info "  $0 mount --vhd-path $vhd_path --mount-point <mount_point>"
        log_info ""
        
        if [[ "$QUIET" == "true" ]]; then
            echo "$vhd_path: created,formatted with UUID=$uuid"
        fi
    else
        # No format option - just show completion message
        log_info "========================================"
        log_info "  Creation completed"
        log_info "========================================"
        log_info ""
        log_info "The VHD file has been created but is not attached or formatted."
        log_info "To use it, you need to:"
        log_info "  1. Attach the VHD:"
        log_info "     $0 attach --vhd-path $vhd_path"
        log_info "  2. Format the VHD:"
        log_info "     $0 format --dev-name <device_name> --type ext4"
        log_info "  3. Mount the formatted VHD:"
        log_info "     $0 mount --vhd-path $vhd_path --mount-point <mount_point>"
        log_info ""
        
        if [[ "$QUIET" == "true" ]]; then
            echo "$vhd_path: created"
        fi
    fi
}

# Function to resize VHD
# Arguments:
#   --mount-point PATH    Mount point (Linux absolute path, e.g., /mnt/data)
#   --size SIZE           New disk size (e.g., 5G, 10G)
#
# Logic Flow:
# ===========
# 1. Validate required parameters
# 2. Check if target mount point exists and is mounted
# 3. Find UUID of target disk
# 4. Calculate total size of all files in target disk
# 5. Convert new_size to bytes
# 6. Determine actual size to use
# 7. Count files in target disk
# 8. Find VHD path by looking it up from the tracking file using UUID
# 9. Create new VHD with temporary name
# 10. Create new VHD file
# 11. Mount new VHD at temporary mount point
# 12. Copy data from target disk to new VHD
# 13. Verify file count and size between source and destination
# 14. Unmount target disk
# 15. Rename target disk to backup name
# 16. Rename new VHD to target disk name
# 17. Mount resized VHD at target mount point
# 18. Report success or error
resize_vhd() {
    # Parse resize command arguments
    local target_mount_point=""
    local new_size=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--mount-point requires a value"
                fi
                if ! validate_mount_point "$2"; then
                    error_exit "Invalid mount point format: $2" 1 "Mount point must be an absolute path (e.g., /mnt/data)"
                fi
                target_mount_point="$2"
                shift 2
                ;;
            --size)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--size requires a value"
                fi
                if ! validate_size_string "$2"; then
                    error_exit "Invalid size format: $2" 1 "Size must be in format: number[K|M|G|T] (e.g., 5G, 500M)"
                fi
                new_size="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown resize option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$target_mount_point" ]]; then
        error_exit "--mount-point is required" 1 "Specify the mount point of the target disk to resize"
    fi
    
    if [[ -z "$new_size" ]]; then
        error_exit "--size is required" 1 "Specify the new size for the disk (e.g., 5G, 10G)"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Resize Operation"
    log_info "========================================"
    log_info ""
    
    # Check if target mount point exists and is mounted
    if [[ ! -d "$target_mount_point" ]]; then
        error_exit "Target mount point does not exist: $target_mount_point"
    fi
    
    # Find UUID of target disk
    local target_uuid=$(wsl_find_uuid_by_mountpoint "$target_mount_point")
    if [[ -z "$target_uuid" ]]; then
        error_exit "No VHD mounted at $target_mount_point" 1 "Please ensure the target disk is mounted first"
    fi
    
    log_success "Found target disk"
    log_info "  UUID: $target_uuid"
    log_info "  Mount Point: $target_mount_point"
    log_info ""
    
    # Get target disk path by finding device and checking lsblk
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$target_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
    fi
    local target_device=$(lsblk -f -J | jq -r --arg UUID "$target_uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
    
    if [[ -z "$target_device" ]]; then
        error_exit "Could not find device for UUID $target_uuid"
    fi
    
    # Calculate total size of all files in target disk
    log_info "Calculating size of files in target disk..."
    local target_size_bytes=$(get_directory_size_bytes "$target_mount_point")
    local target_size_human=$(bytes_to_human "$target_size_bytes")
    
    log_info "  Total size of files: $target_size_human ($target_size_bytes bytes)"
    log_info ""
    
    # Convert new_size to bytes
    local new_size_bytes=$(convert_size_to_bytes "$new_size")
    local required_size_bytes=$((target_size_bytes * 130 / 100))  # Add 30%
    local required_size_human=$(bytes_to_human "$required_size_bytes")
    
    # Determine actual size to use
    local actual_size_bytes=$new_size_bytes
    local actual_size_str="$new_size"
    
    if [[ $new_size_bytes -lt $required_size_bytes ]]; then
        log_warn "Requested size ($new_size) is smaller than required"
        log_info "  Minimum required: $required_size_human (files + 30%)"
        log_info "  Using minimum required size instead"
        actual_size_bytes=$required_size_bytes
        actual_size_str=$required_size_human
        log_info ""
    fi
    
    # Count files in target disk
    log_info "Counting files in target disk..."
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "find '$target_mount_point' -type f | wc -l"
    fi
    local target_file_count=$(find "$target_mount_point" -type f 2>/dev/null | wc -l)
    log_info "  File count: $target_file_count"
    log_info ""
    
    # We need to find the VHD path by looking it up from the tracking file using UUID
    local target_vhd_path=""
    local target_dev_name=""
    
    # Look up VHD path from tracking file using UUID
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} jq -r --arg uuid '$target_uuid' '.mappings[] | select(.uuid == \$uuid) | path(.) | .[-1]' $DISK_TRACKING_FILE" >&2
        fi
        # Find the path (key) that has this UUID
        local normalized_path=$(jq -r --arg uuid "$target_uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        
        if [[ -n "$normalized_path" && "$normalized_path" != "null" ]]; then
            # Convert normalized path back to Windows format (uppercase drive letter)
            # Normalized format is lowercase: c:/vms/disk.vhdx
            # Windows format should be: C:/VMs/disk.vhdx (but we'll use as-is since tracking uses lowercase)
            target_vhd_path="$normalized_path"
            # Extract device name from tracking file if available
            target_dev_name=$(jq -r --arg uuid "$target_uuid" "$JQ_GET_DEV_NAME_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        fi
    fi
    
    # If path lookup failed, try to infer from mount point name as fallback
    if [[ -z "$target_vhd_path" ]]; then
        target_dev_name=$(basename "$target_mount_point")
        local path_help="The VHD path is required for resize operation.
Please ensure the VHD was attached/mounted using vhdm.sh so it's tracked.
Alternatively, you can manually specify the path by modifying the resize command."
        error_exit "Cannot determine VHD path from tracking file" 1 "$path_help"
    fi
    
    log_info "Target VHD path: $target_vhd_path"
    if [[ -n "$target_dev_name" ]]; then
        log_info "Target device: /dev/$target_dev_name"
    fi
    log_info ""
    
    # Create new VHD with temporary name
    local target_vhd_dir=$(dirname "${target_vhd_path}")
    local target_vhd_basename=$(basename "$target_vhd_path" .vhdx)
    target_vhd_basename=$(basename "$target_vhd_basename" .vhd)
    local new_vhd_path="${target_vhd_dir}/${target_vhd_basename}_temp.vhdx"
    local temp_mount_point="${target_mount_point}_temp"
    
    log_info "Creating new VHD"
    log_info "  Path: $new_vhd_path"
    log_info "  Size: $actual_size_str"
    log_info "  Mount Point: $temp_mount_point"
    log_info ""
    
    # Create new VHD
    local new_uuid
    if new_uuid=$(wsl_create_vhd "$new_vhd_path" "$actual_size_str" "ext4" 2>&1); then
        log_success "New VHD created"
        log_info "  New UUID: $new_uuid"
        # Register new VHD for cleanup (will be unregistered on successful completion)
        register_vhd_cleanup "$new_vhd_path" "$new_uuid" ""
    else
        log_error "Failed to create new VHD"
        log_info "$new_uuid"  # Print error message
        error_exit "Failed to create new VHD"
    fi
    log_info ""
    
    # Mount the new VHD
    log_info "Mounting new VHD at $temp_mount_point..."
    if [[ ! -d "$temp_mount_point" ]]; then
        if ! create_mount_point "$temp_mount_point"; then
            error_exit "Failed to create temporary mount point"
        fi
    fi
    
    if wsl_mount_vhd "$new_uuid" "$temp_mount_point"; then
        log_success "New VHD mounted"
    else
        error_exit "Failed to mount new VHD"
    fi
    log_info ""
    
    # Copy all files from target disk to new disk
    log_info "Copying files from target disk to new disk..."
    log_info "  This may take a while depending on data size..."
    
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "sudo rsync -a '$target_mount_point/' '$temp_mount_point/'"
    fi
    
    # Check sudo permissions before rsync operation
    if ! check_sudo_permissions; then
        error_exit "Cannot copy files: sudo permissions required"
    fi
    
    if safe_sudo rsync -a "$target_mount_point/" "$temp_mount_point/" 2>&1; then
        log_success "Files copied successfully"
    else
        error_exit "Failed to copy files"
    fi
    log_info ""
    
    # Verify file count and size
    log_info "Verifying new disk..."
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "find '$temp_mount_point' -type f | wc -l"
    fi
    local new_file_count=$(find "$temp_mount_point" -type f 2>/dev/null | wc -l)
    local new_size_bytes=$(get_directory_size_bytes "$temp_mount_point")
    local new_size_human=$(bytes_to_human "$new_size_bytes")
    
    log_info "  Original file count: $target_file_count"
    log_info "  New file count: $new_file_count"
    log_info "  Original size: $target_size_human"
    log_info "  New size: $new_size_human"
    
    if [[ $new_file_count -ne $target_file_count ]]; then
        local mismatch_help="Expected: $target_file_count, Got: $new_file_count
Aborting resize operation"
        error_exit "File count mismatch!" 1 "$mismatch_help"
    fi
    
    if [[ $new_size_bytes -ne $target_size_bytes ]]; then
        log_warn "Warning: Size differs slightly (expected with filesystem metadata)"
        log_info "  Difference: $((new_size_bytes - target_size_bytes)) bytes"
    fi
    
    log_success "Verification passed"
    log_info ""
    
    # Unmount and detach target disk
    log_info "Unmounting target disk..."
    if ! wsl_umount_vhd "$target_mount_point"; then
        error_exit "Failed to unmount target disk"
    fi
    
    # Get device names from tracking file for history
    local target_dev_name=""
    local new_dev_name=""
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        local normalized_target=$(normalize_vhd_path "$target_vhd_path")
        local normalized_new=$(normalize_vhd_path "$new_vhd_path")
        target_dev_name=$(jq -r --arg path "$normalized_target" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        new_dev_name=$(jq -r --arg path "$normalized_new" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
    fi
    
    if ! wsl_detach_vhd "$target_vhd_path" "$target_uuid" "$target_dev_name"; then
        error_exit "Failed to detach target disk"
    fi
    log_success "Target disk detached"
    log_info ""
    
    # Rename target VHD to backup
    local target_vhd_path_wsl
    target_vhd_path_wsl=$(wsl_convert_path "$target_vhd_path")
    local backup_vhd_path_wsl
    if [[ "$target_vhd_path_wsl" == *.vhdx ]]; then
        backup_vhd_path_wsl="${target_vhd_path_wsl%.vhdx}_bkp.vhdx"
    elif [[ "$target_vhd_path_wsl" == *.vhd ]]; then
        backup_vhd_path_wsl="${target_vhd_path_wsl%.vhd}_bkp.vhd"
    else
        backup_vhd_path_wsl="${target_vhd_path_wsl}_bkp"
    fi
    
    log_info "Renaming target VHD to backup..."
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "mv '$target_vhd_path_wsl' '$backup_vhd_path_wsl'"
    fi
    
    if mv "$target_vhd_path_wsl" "$backup_vhd_path_wsl" 2>/dev/null; then
        log_success "Target VHD renamed to backup"
        log_info "  Backup: $backup_vhd_path_wsl"
    else
        error_exit "Failed to rename target VHD"
    fi
    log_info ""
    
    # Unmount new disk temporarily
    log_info "Unmounting new disk..."
    if ! wsl_umount_vhd "$temp_mount_point"; then
        error_exit "Failed to unmount new disk"
    fi
    
    if ! wsl_detach_vhd "$new_vhd_path" "$new_uuid" "$new_dev_name"; then
        error_exit "Failed to detach new disk"
    fi
    log_success "New disk detached"
    log_info ""
    
    # Unregister new VHD from cleanup tracking (detached successfully, will be renamed)
    unregister_vhd_cleanup "$new_vhd_path" 2>/dev/null || true
    
    # Rename new VHD to target name
    local new_vhd_path_wsl
    new_vhd_path_wsl=$(wsl_convert_path "$new_vhd_path")
    
    log_info "Renaming new VHD to target name..."
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "mv '$new_vhd_path_wsl' '$target_vhd_path_wsl'"
    fi
    
    if mv "$new_vhd_path_wsl" "$target_vhd_path_wsl" 2>/dev/null; then
        log_success "New VHD renamed to target name"
    else
        error_exit "Failed to rename new VHD"
    fi
    log_info ""
    
    # Mount the renamed VHD
    log_info "Mounting resized VHD at $target_mount_point..."
    
    # Attach the VHD (it will get a new UUID since it was formatted)
    # Take snapshot of block devices before attach for device detection
    local old_devs=($(wsl_get_block_devices))
    
    if ! wsl_attach_vhd "$target_vhd_path"; then
        error_exit "Failed to attach resized VHD"
    fi
    
    # Detect new device using snapshot-based detection
    # Pass array elements directly to avoid indirect reference issues
    local final_dev_name
    final_dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
    
    if [[ -z "$final_dev_name" ]]; then
        error_exit "Failed to detect device of resized VHD"
    fi
    
    # Get UUID from device (VHD should be formatted, so UUID should exist)
    local final_uuid
    final_uuid=$(wsl_get_uuid_by_device "$final_dev_name")
    
    if [[ -z "$final_uuid" ]]; then
        error_exit "Failed to detect UUID of resized VHD (device: /dev/$final_dev_name)"
    fi
    
    # Mount the resized VHD
    if wsl_mount_vhd "$final_uuid" "$target_mount_point"; then
        log_success "Resized VHD mounted"
        
        # Update tracking file: remove temp path mapping and save final path mapping
        # The temp VHD was renamed to target path, so we need to:
        # 1. Remove the old temp path mapping (new_vhd_path)
        # 2. Save the target path mapping with the new UUID
        if [[ "$new_vhd_path" != "$target_vhd_path" ]]; then
            tracking_file_remove_mapping "$new_vhd_path" 2>/dev/null || true
        fi
        tracking_file_save_mapping "$target_vhd_path" "$final_uuid" "$target_mount_point" "$final_dev_name"
        
        # Clean up detach history for this path since disk is now attached
        tracking_file_remove_detach_history "$target_vhd_path"
        
        # Unregister from cleanup tracking - operation completed successfully
        unregister_vhd_cleanup "$target_vhd_path" 2>/dev/null || true
    else
        error_exit "Failed to mount resized VHD"
    fi
    log_info ""
    
    # Display final disk info
    log_info "========================================"
    log_info "  Resized VHD Information"
    log_info "========================================"
    log_info "  UUID: $final_uuid"
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$final_uuid"
    log_info ""
    log_info "  Files: $new_file_count"
    log_info "  Data Size: $new_size_human"
    log_info ""
    log_info "  Backup VHD: $backup_vhd_path_wsl"
    log_info "  (You can delete the backup once you verify the resized disk)"
    log_info ""
    log_info "========================================"
    log_info "  Resize operation completed successfully"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        echo "$target_vhd_path: resized to $actual_size_str with UUID=$final_uuid"
    fi
}

# Function to format VHD
# Arguments:
#   --dev-name NAME   VHD device block name (e.g., sdd, sde)
#   --uuid UUID       VHD UUID
#   --type TYPE       Filesystem type [default: ext4]
#
# Logic Flow:
# ===========
# 1. Validate required parameters
# 2. Check if device exists and is formatted
# 3. If formatted, prompt for confirmation
# 4. If not formatted, format the device
# 5. Report success or error
#
# Note: Unlike delete_vhd(), this function does NOT remove the mapping from
#       the tracking file. The mapping is preserved so the VHD can be easily
#       re-attached later. Only delete_vhd() removes mappings entirely.
format_vhd_command() {
    # Parse format command arguments
    local dev_name=""
    local uuid=""
    local old_uuid=""  # Store original UUID for tracking file lookup when reformatting
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    local format_type="$default_fs"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dev-name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--dev-name requires a value"
                fi
                if ! validate_device_name "$2"; then
                    error_exit "Invalid device name format: $2" 1 "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde)"
                fi
                dev_name="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                uuid="$2"
                shift 2
                ;;
            --type)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--type requires a value"
                fi
                if ! validate_filesystem_type "$2"; then
                    error_exit "Invalid filesystem type: $2" 1 "Supported types: ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat"
                fi
                format_type="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown option: $1" 1 "Use --help to see available options"
                ;;
        esac
    done
    
    # Validate that at least name or UUID is provided
    if [[ -z "$dev_name" && -z "$uuid" ]]; then
        local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
        local format_help="Usage: $0 format [OPTIONS]

Options:
  --dev-name NAME   - VHD device block name (e.g., sdd, sde)
  --uuid UUID       - VHD UUID
  --type TYPE       - Filesystem type [default: $default_fs]

Examples:
  $0 format --dev-name sdd --type ext4
  $0 format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4

To find attached VHDs, run: $0 status --all"
        error_exit "Either --dev-name or --uuid is required" 1 "$format_help"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Format Operation"
    log_info "========================================"
    log_info ""
    
    local target_identifier=""
    
    # Determine device name based on provided arguments
    if [[ -n "$uuid" ]]; then
        # Check if UUID exists and if it's already formatted
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
        fi
        dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        
        if [[ -z "$dev_name" ]]; then
            local uuid_help="The UUID might be incorrect or the VHD is not attached.
To find attached VHDs, run: $0 status --all"
            error_exit "No device found with UUID: $uuid" 1 "$uuid_help"
        fi
        
        # Validate device name format for security before use in mkfs
        if ! validate_device_name "$dev_name"; then
            local device_help="Device name must match pattern: sd[a-z]+ (e.g., sdd, sde, sdaa)
This is a security check to prevent command injection."
            error_exit "Invalid device name format: $dev_name" 1 "$device_help"
        fi
        
        # Warn user that disk is already formatted
        log_warn "WARNING: Device /dev/$dev_name is already formatted"
        log_info "  Current UUID: $uuid"
        log_info ""
        log_info "Formatting will destroy all existing data and generate a new UUID."
        
        if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
            echo -n "Are you sure you want to format /dev/$dev_name? (yes/no): "
            read -r confirmation
            
            if [[ "$confirmation" != "yes" ]]; then
                log_info "Format operation cancelled."
                exit 0
            fi
            log_info ""
        elif [[ "$YES" == "true" ]]; then
            log_info "Auto-confirming format (--yes flag set)..."
            log_info ""
        fi
        
        target_identifier="UUID $uuid"
        old_uuid="$uuid"  # Store for tracking file update after formatting
    else
        # Using device name directly
        target_identifier="device name $dev_name"
        
        # Validate device exists
        if [[ ! -b "/dev/$dev_name" ]]; then
            local device_help="Please check the device name is correct.
To find attached VHDs, run: $0 status --all"
            error_exit "Block device /dev/$dev_name does not exist" 1 "$device_help"
        fi
        
        # Check if device has existing UUID (already formatted)
        # Use safe_sudo_capture for blkid command
        local existing_uuid
        existing_uuid=$(safe_sudo_capture blkid -s UUID -o value "/dev/$dev_name" 2>/dev/null)
        if [[ -n "$existing_uuid" ]]; then
            log_warn "WARNING: Device /dev/$dev_name is already formatted"
            log_info "  Current UUID: $existing_uuid"
            log_info ""
            log_info "Formatting will destroy all existing data and generate a new UUID."
            
            if [[ "$QUIET" == "false" ]]; then
                echo -n "Are you sure you want to format /dev/$dev_name? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    log_info "Format operation cancelled."
                    exit 0
                fi
                log_info ""
            fi
        else
            log_success "Device /dev/$dev_name is not formatted"
            log_info ""
        fi
    fi
    
    log_info "Formatting device /dev/$dev_name with $format_type..."
    log_info "  Target: $target_identifier"
    log_info ""
    
    # Format using helper function
    local new_uuid=$(format_vhd "$dev_name" "$format_type")
    if [[ $? -ne 0 || -z "$new_uuid" ]]; then
        error_exit "Failed to format device /dev/$dev_name"
    fi
    
    log_success "VHD formatted successfully"
    log_info "  Device: /dev/$dev_name"
    log_info "  New UUID: $new_uuid"
    log_info "  Filesystem: $format_type"
    
    # Try to update tracking file with new UUID
    # Priority: 1) Look up by old UUID (reformatting), 2) Look up by device name (new format)
    local tracked_path=""
    
    # First try to look up by old UUID (when reformatting a previously formatted VHD)
    if [[ -n "$old_uuid" ]]; then
        tracked_path=$(tracking_file_lookup_path_by_uuid "$old_uuid")
        if [[ -n "$tracked_path" ]]; then
            log_debug "Found tracked path by old UUID: $tracked_path"
        fi
    fi
    
    # Fall back to looking up by device name (for unformatted VHDs tracked during attach)
    if [[ -z "$tracked_path" ]]; then
        tracked_path=$(tracking_file_lookup_path_by_dev_name "$dev_name")
        if [[ -n "$tracked_path" ]]; then
            log_debug "Found tracked path by device name: $tracked_path"
        fi
    fi
    
    # Update tracking file if we found a tracked path
    if [[ -n "$tracked_path" ]]; then
        tracking_file_save_mapping "$tracked_path" "$new_uuid" "" "$dev_name"
        log_debug "Updated tracking file: $tracked_path → $new_uuid"
    else
        log_debug "No tracked path found for device $dev_name (VHD may not be tracked)"
    fi
    
    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$new_uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Format operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        echo "/dev/$dev_name: formatted with UUID=$new_uuid"
    fi
}

# Function to attach VHD
# Arguments:
#   --vhd-path PATH       VHD file path (Windows format, required)
#   --name NAME           VHD name for WSL attachment [default: disk]
#
# Logic Flow:
# ===========
# 1. Validate required parameters
# 2. Convert Windows path to WSL path to check if VHD exists
# 3. Take snapshot of current block devices before attaching
#    - Only block devices needed (device-first detection approach)
#    - Snapshot is filtered to only include dynamically attached VHDs (sd[d-z] pattern)
# 4. Attempt to attach the VHD (will succeed if not attached, fail silently if already attached)
# 5. Detect new device using snapshot-based detection (detect_new_device_after_attach)
#    - Works for both formatted and unformatted VHDs
#    - Filters old devices before sleep to ensure pre-attach state
#    - Excludes system disks (sda, sdb, sdc) to avoid false positives
# 6. Get UUID from device if available (wsl_get_uuid_by_device)
#    - UUID will be empty if VHD is unformatted
#    - UUID is only available for formatted VHDs
# 7. Update cleanup registration and save mapping to tracking file
#    - Mapping includes device name for future reference
# 8. Report success or error
#
# Note: Unlike detach_vhd(), this function does NOT remove the mapping from
#       the tracking file. The mapping is preserved so the VHD can be easily
#       re-attached later. Only delete_vhd() removes mappings entirely.
attach_vhd() {
    # Parse attach command arguments
    local vhd_path=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                vhd_path="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown option: $1" 1 "Use --help to see available options"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$vhd_path" ]]; then
        error_exit "VHD path is required. Use --vhd-path option."
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path")
    if [[ ! -e "$vhd_path_wsl" ]]; then
        error_exit "VHD file does not exist: $vhd_path (WSL path: $vhd_path_wsl)"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Attach Operation"
    log_info "========================================"
    log_info ""
    
    # Take snapshot of current block devices before attaching
    # This is used to detect the newly attached device after attach
    local old_devs=($(wsl_get_block_devices))
    log_debug "Captured old_devs array (count: ${#old_devs[@]}): ${old_devs[*]}"
    
    # Try to attach the VHD (will succeed if not attached, fail silently if already attached)
    local uuid=""
    local dev_name=""
    local script_name="${0##*/}"
    
    if wsl_attach_vhd "$vhd_path" 2>/dev/null; then
        # Register VHD for cleanup (will be unregistered on successful completion)
        register_vhd_cleanup "$vhd_path" "" ""
        log_success "VHD attached to WSL"
        log_info "  Path: $vhd_path"
        log_info ""
        
        # Detect new device using snapshot-based detection
        # This works for both formatted and unformatted VHDs
        # Pass array elements directly to avoid indirect reference issues
        dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
        
        if [[ -n "$dev_name" ]]; then
            # Device detected - now try to get UUID from the device
            # This will succeed if VHD is formatted, fail if unformatted
            uuid=$(wsl_get_uuid_by_device "$dev_name")
            
            # Report device detection
            log_success "Device detected"
            log_info "  Device: /dev/$dev_name"
            
            if [[ -n "$uuid" ]]; then
                # UUID found - VHD is formatted
                log_info "  UUID: $uuid"
                
                # Save mapping to tracking file with device name
                tracking_file_save_mapping "$vhd_path" "$uuid" "" "$dev_name"
                
                # Clean up detach history for this path since disk is now attached
                tracking_file_remove_detach_history "$vhd_path"
            else
                # Device detected but no UUID - VHD is unformatted
                log_warn "Warning: VHD attached but has no filesystem UUID (unformatted)"
                log_info "  To format the VHD, run:"
                log_info "    $0 format --dev-name $dev_name --type ext4"
                
                # Save mapping to tracking file with empty UUID (will be updated after formatting)
                # This allows format command to find the path by device name and update UUID
                tracking_file_save_mapping "$vhd_path" "" "" "$dev_name"
                
                # Clean up detach history for this path since disk is now attached
                tracking_file_remove_detach_history "$vhd_path"
            fi
            
            # Unregister from cleanup tracking - operation completed successfully
            unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
        else
            # Device detection failed
            log_warn "Warning: Could not automatically detect device"
            log_info "  The VHD was attached successfully but device detection failed."
            log_info "  You can find the device using: ./${script_name} status --all"
        fi
    else
        # Attachment failed - VHD might already be attached
        log_warn "VHD attachment failed - checking if already attached..."
        log_info ""
        
        # Try to find the UUID with multi-VHD safety
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        # Handle discovery result with consistent error handling
        handle_uuid_discovery_result "$discovery_result" "$uuid" "attach" "$vhd_path"
        
        if wsl_is_vhd_attached "$uuid"; then
            log_success "VHD is already attached to WSL"
            log_info "  UUID: $uuid"
            
            # Get device name
            if [[ "$DEBUG" == "true" ]]; then
                log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
            fi
            local dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            [[ -n "$dev_name" ]] && log_info "  Device: /dev/$dev_name"
            
            # Save mapping to tracking file (idempotent - updates if exists) with device name
            tracking_file_save_mapping "$vhd_path" "$uuid" "" "$dev_name"
            
            # Clean up detach history for this path since disk is now attached
            tracking_file_remove_detach_history "$vhd_path"
            
            # Unregister from cleanup tracking - operation completed successfully
            unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
        else
            local attach_help="The VHD might already be attached with a different name or path.
Try running: ./vhdm.sh status --all"
            error_exit "Failed to attach VHD" 1 "$attach_help"
        fi
    fi
    
    log_info ""
    [[ -n "$uuid" ]] && [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Attach operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if [[ -n "$uuid" ]]; then
            echo "$vhd_path ($uuid): attached"
        else
            echo "$vhd_path: attached (UUID unknown)"
        fi
    fi
}

# Function to show detach history
# Arguments:
#   --limit N                Number of detach events to show [default: 10, max: 50]
#   --vhd-path PATH           Show last detach event for specific VHD path
#
# Logic Flow:
# ===========
# 1. Validate command arguments
# 2. Show history for specific path if provided
# 3. Show recent history if no path provided
# 4. Report success or error
# 5. Return JSON array of detach events
history_vhd() {
    # Parse history command arguments
    local default_limit="${DEFAULT_HISTORY_LIMIT:-10}"
    local limit="$default_limit"
    local show_path=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--limit requires a value"
                fi
                limit="$2"
                shift 2
                ;;
            --vhd-path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--vhd-path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                show_path="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown history option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    log_info "========================================"
    log_info "  VHD Detach History"
    log_info "========================================"
    log_info ""
    
    if [[ -n "$show_path" ]]; then
        # Show history for specific path
        local history_json=$(tracking_file_get_last_detach_for_path "$show_path")
        
        if [[ -n "$history_json" ]]; then
            if [[ "$QUIET" == "true" ]]; then
                echo "$history_json"
            else
                local path=$(echo "$history_json" | jq -r '.path')
                local uuid=$(echo "$history_json" | jq -r '.uuid')
                local dev_name=$(echo "$history_json" | jq -r '.dev_name // empty')
                local timestamp=$(echo "$history_json" | jq -r '.timestamp')
                
                echo "Path: $path"
                echo "UUID: $uuid"
                [[ -n "$dev_name" ]] && echo "Device: /dev/$dev_name"
                echo "Last detached: $timestamp"
            fi
        else
            log_info "No detach history found for path: $show_path"
            [[ "$QUIET" == "true" ]] && echo "{}"
        fi
    else
        # Show recent history
        local history_json=$(tracking_file_get_detach_history "$limit")
        
        if [[ "$QUIET" == "true" ]]; then
            echo "$history_json"
        else
            local count=$(echo "$history_json" | jq 'length')
            
            if [[ "$count" -eq 0 ]]; then
                log_info "No detach history available"
            else
                log_info "Showing last $count detach events:"
                log_info ""
                
                echo "$history_json" | jq -r "$JQ_FORMAT_HISTORY_ENTRY"
            fi
        fi
    fi
    
    log_info "========================================"
}

# Function to mount VHD
if [[ $# -eq 0 ]]; then
    show_usage
fi

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -y|--yes)
            YES=true
            shift
            ;;
        -h|--help|help)
            show_usage
            ;;
        attach|format|mount|umount|unmount|detach|status|create|delete|resize|history)
            COMMAND="$1"
            shift
            break
            ;;
        *)
            echo -e "${RED}Error: Unknown option or command '$1'${NC}"
            echo
            show_usage
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    attach)
        attach_vhd "$@"  # Pass remaining arguments to attach_vhd
        ;;
    format)
        format_vhd_command "$@"  # Pass remaining arguments to format_vhd_command
        ;;
    mount)
        mount_vhd "$@"  # Pass remaining arguments to mount_vhd
        ;;
    umount|unmount)
        umount_vhd "$@"  # Pass remaining arguments to umount_vhd
        ;;
    detach)
        detach_vhd "$@"  # Pass remaining arguments to detach_vhd
        ;;
    status)
        show_status "$@"  # Pass remaining arguments to show_status
        ;;
    create)
        create_vhd "$@"  # Pass remaining arguments to create_vhd
        ;;
    delete)
        delete_vhd "$@"  # Pass remaining arguments to delete_vhd
        ;;
    resize)
        resize_vhd "$@"  # Pass remaining arguments to resize_vhd
        ;;
    history)
        history_vhd "$@"  # Pass remaining arguments to history_vhd
        ;;
    *)
        echo -e "${RED}Error: No command specified${NC}"
        echo
        show_usage
        ;;
esac

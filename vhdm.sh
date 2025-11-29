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

# Auto-sync mappings on startup (removes stale mappings for detached VHDs)
# This runs silently and only if AUTO_SYNC_MAPPINGS is enabled in config
if [[ "${AUTO_SYNC_MAPPINGS:-true}" == "true" ]]; then
    tracking_file_sync_mappings_silent
fi

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
    echo "  history [OPTIONS]        - Show tracking history (mappings + detach history)"
    echo "  sync [OPTIONS]           - Synchronize tracking file with actual system state"
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
    echo "  --vhd-path PATH           - [optional] Show info for specific VHD path (mapping + detach history)"
    echo "  Note: Shows current mappings (attached VHDs) and detach history. Syncs tracking file first."
    echo
    echo "Sync Command Options:"
    echo "  --dry-run                - [optional] Show what would be removed without making changes"
    echo "  Note: Removes stale mappings (detached VHDs) and history entries (deleted VHD files)."
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
    echo "  $0 sync"
    echo "  $0 sync --dry-run"
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
                log_debug "Found VHD UUID: $uuid"
            fi
        # Try to find UUID by mount point if provided
        elif [[ -n "$mount_point" ]]; then
            uuid=$(wsl_find_uuid_by_mountpoint "$mount_point")
            if [[ -n "$uuid" ]]; then
                log_debug "Found UUID by mount point: $uuid"
            fi
        fi
    fi
    
    # If --all flag, show all attached VHDs
    if [[ "$show_all" == "true" ]]; then
        local all_uuids
        all_uuids=$(wsl_get_disk_uuids)
        
        if [[ -z "$all_uuids" ]]; then
            echo "No VHDs attached to WSL"
            exit 0
        fi
        
        if [[ "$QUIET" == "true" ]]; then
            # Quiet mode - simple output with path from tracking file
            while IFS= read -r disk_uuid; do
                local tracked_path=""
                if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                    tracked_path=$(jq -r --arg uuid "$disk_uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
                    [[ "$tracked_path" == "null" || -z "$tracked_path" ]] && tracked_path=""
                fi
                
                if wsl_is_vhd_mounted "$disk_uuid"; then
                    if [[ -n "$tracked_path" ]]; then
                        echo "$tracked_path ($disk_uuid): attached,mounted"
                    else
                        echo "$disk_uuid: attached,mounted"
                    fi
                else
                    if [[ -n "$tracked_path" ]]; then
                        echo "$tracked_path ($disk_uuid): attached"
                    else
                        echo "$disk_uuid: attached"
                    fi
                fi
            done <<< "$all_uuids"
        else
            # Verbose mode - table output
            log_debug "Displaying all attached VHDs"
            
            print_table_title "All Attached VHD Disks"
            
            # Define column widths: UUID(36), Device(8), Available(10), Used(6), Mount Point(25), Status(12)
            local col_widths="36,8,10,6,25,12"
            
            # Print table header
            print_table_header "$col_widths" "UUID" "Device" "Available" "Used" "Mount Point" "Status"
            
            # Collect data and print rows
            local paths_found=false
            local path_info=""
            while IFS= read -r disk_uuid; do
                local device_name fsavail fsuse mount_point status_text tracked_path
                
                # Get device info
                device_name=$(lsblk -f -J | jq -r --arg UUID "$disk_uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
                fsavail=$(lsblk -f -J | jq -r --arg UUID "$disk_uuid" "$JQ_GET_FSAVAIL_BY_UUID" 2>/dev/null)
                fsuse=$(lsblk -f -J | jq -r --arg UUID "$disk_uuid" "$JQ_GET_FSUSE_BY_UUID" 2>/dev/null)
                mount_point=$(lsblk -f -J | jq -r --arg UUID "$disk_uuid" "$JQ_GET_MOUNTPOINTS_BY_UUID" 2>/dev/null | grep -v "null" | head -n 1)
                
                # Try to get path from tracking file
                tracked_path=""
                if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                    tracked_path=$(jq -r --arg uuid "$disk_uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
                    [[ "$tracked_path" == "null" || -z "$tracked_path" ]] && tracked_path=""
                fi
                
                if [[ -n "$tracked_path" ]]; then
                    paths_found=true
                    path_info="${path_info}  ${device_name}: ${tracked_path}\n"
                fi
                
                # Handle null/empty values
                [[ -z "$device_name" || "$device_name" == "null" ]] && device_name="-"
                [[ -z "$fsavail" || "$fsavail" == "null" ]] && fsavail="-"
                [[ -z "$fsuse" || "$fsuse" == "null" ]] && fsuse="-"
                [[ -z "$mount_point" || "$mount_point" == "null" ]] && mount_point="-"
                
                # Determine status
                if wsl_is_vhd_mounted "$disk_uuid"; then
                    status_text="Mounted"
                else
                    status_text="Attached"
                fi
                
                # Print row
                print_table_row "$col_widths" "$disk_uuid" "$device_name" "$fsavail" "$fsuse" "$mount_point" "$status_text"
            done <<< "$all_uuids"
            
            # Print table footer
            print_table_footer "$col_widths"
            
            # Show path information if found
            if [[ "$paths_found" == "true" ]]; then
                echo ""
                echo "VHD Paths (from tracking file):"
                echo -e "$path_info"
            else
                echo ""
                echo "Note: No VHD paths found in tracking file."
                echo "      Use 'status --vhd-path <path>' to verify a specific VHD."
            fi
        fi
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
    
    # Try to look up VHD path from tracking file if not provided
    if [[ -z "$vhd_path" ]]; then
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local found_path
            found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
            
            if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                vhd_path="$found_path"
                log_debug "Found VHD path in tracking file: $vhd_path"
            fi
        fi
    fi
    
    # Show status for specific VHD
    if [[ "$QUIET" == "true" ]]; then
        # Quiet mode - simple output
        if wsl_is_vhd_attached "$uuid"; then
            if wsl_is_vhd_mounted "$uuid"; then
                if [[ -n "$vhd_path" ]]; then
                    echo "$vhd_path ($uuid): attached,mounted"
                else
                    echo "$uuid: attached,mounted"
                fi
            else
                if [[ -n "$vhd_path" ]]; then
                    echo "$vhd_path ($uuid): attached"
                else
                    echo "$uuid: attached"
                fi
            fi
        else
            if [[ -n "$vhd_path" ]]; then
                echo "$vhd_path ($uuid): not found"
            else
                echo "$uuid: not found"
            fi
        fi
    else
        # Verbose mode - table output
        log_debug "Displaying status for VHD: $uuid"
        
        print_table_title "VHD Disk Status"
        
        if wsl_is_vhd_attached "$uuid"; then
            local device_name fsavail fsuse actual_mount_point status_text status_color
            
            # Get device info
            device_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            fsavail=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_FSAVAIL_BY_UUID" 2>/dev/null)
            fsuse=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_FSUSE_BY_UUID" 2>/dev/null)
            actual_mount_point=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_MOUNTPOINTS_BY_UUID" 2>/dev/null | grep -v "null" | head -n 1)
            
            # Handle null/empty values
            [[ -z "$device_name" || "$device_name" == "null" ]] && device_name="N/A"
            [[ -z "$fsavail" || "$fsavail" == "null" ]] && fsavail="N/A"
            [[ -z "$fsuse" || "$fsuse" == "null" ]] && fsuse="N/A"
            [[ -z "$actual_mount_point" || "$actual_mount_point" == "null" ]] && actual_mount_point="-"
            
            # Determine status
            if wsl_is_vhd_mounted "$uuid"; then
                status_text="Mounted"
            else
                status_text="Attached (not mounted)"
            fi
            
            # Print info table (key-value format)
            local key_width=14
            local val_width=50
            local kv_widths="$key_width,$val_width"
            
            print_table_header "$kv_widths" "Property" "Value"
            
            if [[ -n "$vhd_path" ]]; then
                print_table_row "$kv_widths" "Path" "$vhd_path"
            fi
            print_table_row "$kv_widths" "UUID" "$uuid"
            print_table_row "$kv_widths" "Device" "/dev/$device_name"
            print_table_row "$kv_widths" "Available" "$fsavail"
            print_table_row "$kv_widths" "Used" "$fsuse"
            print_table_row "$kv_widths" "Mount Point" "$actual_mount_point"
            print_table_row "$kv_widths" "Status" "$status_text"
            print_table_footer "$kv_widths"
        else
            # VHD not attached - show minimal info
            local key_width=14
            local val_width=50
            local kv_widths="$key_width,$val_width"
            
            print_table_header "$kv_widths" "Property" "Value"
            
            if [[ -n "$vhd_path" ]]; then
                print_table_row "$kv_widths" "Path" "$vhd_path"
            fi
            print_table_row "$kv_widths" "UUID" "$uuid"
            print_table_row "$kv_widths" "Status" "Not Found"
            print_table_footer "$kv_widths"
        fi
    fi
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
    
    log_debug "Mount operation starting"
    
    local uuid=""
    local found_path=""  # Path found in tracking file when vhd_path not provided
    local mount_status="mounted"
    local was_attached="No"
    
    # ========================================================================
    # SCENARIO 2: --dev-name provided (device already attached)
    # ========================================================================
    if [[ -n "$dev_name" ]]; then
        log_debug "Using device name: $dev_name"
        
        if ! wsl_device_exists "$dev_name"; then
            error_exit "Device $dev_name does not exist" 1 "Use 'lsblk' or '$0 status --all' to see available devices"
        fi
        
        uuid=$(wsl_get_uuid_by_device "$dev_name")
        if [[ -z "$uuid" ]]; then
            error_exit "Device $dev_name exists but has no filesystem UUID" 1 "The device may not be formatted. Use '$0 format --dev-name $dev_name --type ext4' to format it."
        fi
        
        log_debug "Found UUID: $uuid for device: $dev_name"
        
        if [[ -z "$vhd_path" ]]; then
            if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
                
                if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                    log_debug "UUID $uuid found in tracking file for path: $found_path"
                    
                    local current_mount_points
                    current_mount_points=$(jq -r --arg path "$found_path" '.mappings[$path].mount_points // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
                    
                    if tracking_file_save_mapping "$found_path" "$uuid" "$current_mount_points" "$dev_name"; then
                        tracking_file_remove_detach_history "$found_path"
                    fi
                fi
            fi
        fi
    
    # ========================================================================
    # SCENARIO 1 or 3: --vhd-path provided
    # ========================================================================
    elif [[ -n "$vhd_path" ]]; then
        local vhd_path_wsl
        vhd_path_wsl=$(wsl_convert_path "$vhd_path")
        if [[ ! -e "$vhd_path_wsl" ]]; then
            error_exit "VHD file does not exist at $vhd_path"
        fi
        
        local old_devs=($(wsl_get_block_devices))
        
        local attach_output=""
        wsl_attach_vhd "$vhd_path" "attach_output"
        local attach_result=$?
        
        if [[ $attach_result -eq 0 ]]; then
            # SCENARIO 1: Successfully attached
            was_attached="Yes"
            log_debug "VHD attached successfully"
            
            register_vhd_cleanup "$vhd_path" "" ""
            
            dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
            
            if [[ -z "$dev_name" ]]; then
                error_exit "Failed to detect device of attached VHD"
            fi
            
            uuid=$(wsl_get_uuid_by_device "$dev_name")
            
            if [[ -z "$uuid" ]]; then
                local format_help="The VHD is attached but not formatted.
  Device: /dev/$dev_name

To format the VHD, run:
  $0 format --dev-name $dev_name --type ext4"
                error_exit "VHD has no filesystem" 1 "$format_help"
            fi
            
            if [[ -n "$uuid" ]]; then
                unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
                register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"
            fi
            
            log_debug "Detected UUID: $uuid, Device: /dev/$dev_name"
            tracking_file_remove_detach_history "$vhd_path"
            
        elif [[ "$attach_output" == *"WSL_E_USER_VHD_ALREADY_ATTACHED"* ]] || [[ "$attach_output" == *"already attached"* ]] || [[ "$attach_output" == *"already mounted"* ]]; then
            # SCENARIO 3: VHD already attached
            log_debug "VHD is already attached, searching for UUID..."
            
            local discovery_result
            uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
            discovery_result=$?
            
            handle_uuid_discovery_result "$discovery_result" "$uuid" "mount" "$vhd_path"
            
            if [[ -z "$uuid" ]]; then
                error_exit "Cannot mount VHD: UUID not found for $vhd_path" 1 "The VHD may be attached but not formatted, or there may be multiple VHDs attached. Use '$0 status --all' to see all attached VHDs."
            fi
            
            dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            tracking_file_remove_detach_history "$vhd_path"
            
        else
            error_exit "Failed to attach VHD: $attach_output"
        fi
    fi
    
    # ========================================================================
    # COMMON MOUNT LOGIC
    # ========================================================================
    local current_mount_point
    current_mount_point=$(wsl_get_vhd_mount_point "$uuid")
    
    if [[ -n "$current_mount_point" ]] && [[ "$current_mount_point" == "$mount_point" ]]; then
        mount_status="already mounted"
        tracking_file_update_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" "$found_path"
        
        if [[ -n "$vhd_path" ]]; then
            unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
        fi
    else
        if [[ -n "$current_mount_point" ]]; then
            log_debug "VHD is mounted at a different location: $current_mount_point"
        fi
        
        if [[ ! -d "$mount_point" ]]; then
            log_debug "Creating mount point: $mount_point"
            if ! create_mount_point "$mount_point"; then
                error_exit "Failed to create mount point"
            fi
        fi
        
        log_debug "Mounting VHD to $mount_point..."
        if wsl_mount_vhd "$uuid" "$mount_point"; then
            mount_status="mounted"
            
            tracking_file_update_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" "$found_path"
            
            if [[ -n "$vhd_path" ]] && [[ -n "$dev_name" ]]; then
                local normalized_path=$(normalize_vhd_path "$vhd_path")
                if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                    local current_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
                    if [[ -z "$current_dev_name" || "$current_dev_name" == "null" ]]; then
                        tracking_file_save_mapping "$vhd_path" "$uuid" "$mount_point" "$dev_name"
                    fi
                fi
            fi
            
            if [[ -n "$vhd_path" ]]; then
                unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
            fi
        else
            error_exit "Failed to mount VHD"
        fi
    fi

    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        local display_path="${vhd_path:-$found_path}"
        if wsl_is_vhd_mounted "$uuid"; then
            if [[ -n "$display_path" ]]; then
                echo "$display_path ($uuid): attached,mounted"
            else
                echo "$dev_name ($uuid): mounted"
            fi
        else
            if [[ -n "$display_path" ]]; then
                echo "$display_path ($uuid): mount failed"
            else
                echo "$dev_name ($uuid): mount failed"
            fi
        fi
        return 0
    fi
    
    # Display result table
    print_table_title "VHD Mount Result"
    
    local kv_widths="16,50"
    print_table_header "$kv_widths" "Property" "Value"
    [[ -n "$vhd_path" ]] && print_table_row "$kv_widths" "Path" "$vhd_path"
    [[ -z "$vhd_path" && -n "$found_path" ]] && print_table_row "$kv_widths" "Path" "$found_path"
    print_table_row "$kv_widths" "UUID" "$uuid"
    [[ -n "$dev_name" ]] && print_table_row "$kv_widths" "Device" "/dev/$dev_name"
    print_table_row "$kv_widths" "Mount Point" "$mount_point"
    print_table_row "$kv_widths" "Status" "$mount_status"
    [[ "$was_attached" == "Yes" ]] && print_table_row "$kv_widths" "Attached" "Yes (newly)"
    print_table_footer "$kv_widths"
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
        log_debug "Using device name: $dev_name"
        
        # Validate device exists in system
        if ! wsl_device_exists "$dev_name"; then
            error_exit "Device $dev_name does not exist" 1 "Use 'lsblk' or '$0 status --all' to see available devices"
        fi
        
        # Get UUID from device name (requires device to be formatted)
        uuid=$(wsl_get_uuid_by_device "$dev_name")
        if [[ -z "$uuid" ]]; then
            error_exit "Device $dev_name exists but has no filesystem UUID" 1 "The device may not be formatted. Use '$0 format --dev-name $dev_name --type ext4' to format it."
        fi
        
        log_debug "Found UUID: $uuid for device: $dev_name"
    
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
    
    # ========================================================================
    # SCENARIO 3: --mount-point provided
    # ========================================================================
    # Try to find UUID by mount point
    # ========================================================================
    elif [[ -n "$mount_point" ]]; then
        # Try to find UUID by mount point
        uuid=$(wsl_find_uuid_by_mountpoint "$mount_point")
        if [[ -n "$uuid" ]]; then
            log_debug "Discovered UUID from mount point: $uuid"
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
    
    # Try to look up VHD path from tracking file if not provided
    if [[ -z "$vhd_path" ]]; then
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local found_path
            found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
            
            if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                vhd_path="$found_path"
                log_debug "Found VHD path in tracking file: $vhd_path"
            fi
        fi
    fi
    
    log_debug "Unmount operation starting"
    
    local unmount_status="unmounted"
    local detach_status=""
    local original_mount_point=""
    
    if ! wsl_is_vhd_attached "$uuid"; then
        if [[ "$QUIET" == "true" ]]; then
            if [[ -n "$vhd_path" ]]; then
                echo "$vhd_path ($uuid): not attached"
            else
                echo "($uuid): not attached"
            fi
        else
            echo ""
            echo "VHD is not attached to WSL. Nothing to do."
        fi
        exit 0
    fi
    
    # First, unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$uuid"; then
        if [[ -z "$mount_point" ]]; then
            mount_point=$(wsl_get_vhd_mount_point "$uuid")
        fi
        original_mount_point="$mount_point"
        
        log_debug "Unmounting VHD from $mount_point..."
        if wsl_umount_vhd "$mount_point"; then
            unmount_status="unmounted"
            tracking_file_remove_mount_point "$vhd_path" "$dev_name" "$uuid" "$mount_point" ""
        else
            error_exit "Failed to unmount VHD"
        fi
    else
        unmount_status="was not mounted"
    fi
    
    # Then, detach from WSL (only if path was provided)
    if [[ -n "$vhd_path" ]]; then
        log_debug "Detaching VHD from WSL..."
        local history_dev_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$vhd_path")
            history_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        if wsl_detach_vhd "$vhd_path" "$uuid" "$history_dev_name"; then
            detach_status="detached"
            tracking_file_save_detach_history "$vhd_path" "$uuid" "$history_dev_name"
            tracking_file_remove_mapping "$vhd_path"
        else
            error_exit "Failed to detach VHD from WSL"
        fi
    else
        detach_status="still attached"
    fi

    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        if [[ "$detach_status" == "detached" ]]; then
            echo "$vhd_path ($uuid): detached"
        elif [[ -n "$vhd_path" ]]; then
            echo "$vhd_path ($uuid): unmounted,attached"
        else
            echo "($uuid): unmounted,attached"
        fi
        return 0
    fi
    
    # Display result table
    print_table_title "VHD Unmount Result"
    
    local kv_widths="16,50"
    print_table_header "$kv_widths" "Property" "Value"
    [[ -n "$vhd_path" ]] && print_table_row "$kv_widths" "Path" "$vhd_path"
    print_table_row "$kv_widths" "UUID" "$uuid"
    [[ -n "$dev_name" ]] && print_table_row "$kv_widths" "Device" "/dev/$dev_name"
    [[ -n "$original_mount_point" ]] && print_table_row "$kv_widths" "Mount Point" "$original_mount_point"
    print_table_row "$kv_widths" "Unmount" "$unmount_status"
    print_table_row "$kv_widths" "Detach" "$detach_status"
    print_table_footer "$kv_widths"
    
    # Show note if not detached
    if [[ "$detach_status" == "still attached" ]]; then
        echo ""
        echo "Note: VHD path required to detach. Run:"
        echo "  $0 detach --vhd-path <VHD_PATH>"
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
    
    log_debug "Detach operation starting"
    
    local original_mount_point=""
    local was_mounted="No"
    
    # ========================================================================
    # SCENARIO 1: --dev-name provided
    # ========================================================================
    if [[ -n "$dev_name" ]]; then
        log_debug "Using device name: $dev_name"
        
        if ! wsl_device_exists "$dev_name"; then
            error_exit "Device $dev_name does not exist" 1 "Use 'lsblk' or '$0 status --all' to see available devices"
        fi
        
        uuid=$(wsl_get_uuid_by_device "$dev_name")
        if [[ -z "$uuid" ]]; then
            error_exit "Device $dev_name exists but has no filesystem UUID" 1 "The device may not be formatted. Use '$0 format --dev-name $dev_name --type ext4' to format it."
        fi
        
        log_debug "Found UUID: $uuid for device: $dev_name"
    
    # ========================================================================
    # SCENARIO 2: --uuid provided
    # ========================================================================
    elif [[ -n "$uuid" ]]; then
        log_debug "Using UUID: $uuid"
        
        if [[ "$DEBUG" == "true" ]]; then
            log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
        fi
        dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
    
    # ========================================================================
    # SCENARIO 3: --vhd-path provided
    # ========================================================================
    elif [[ -n "$vhd_path" ]]; then
        log_debug "Using VHD path: $vhd_path"
        
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 0 && -n "$uuid" ]]; then
            dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        elif [[ $discovery_result -eq 2 ]]; then
            log_debug "Multiple VHDs attached - proceeding with path-based detach"
            uuid=""
        else
            log_debug "Could not discover UUID - VHD may not be attached"
            uuid=""
        fi
    fi
    
    # Check if VHD is attached (only if we have UUID)
    if [[ -n "$uuid" ]]; then
        # Look up VHD path from tracking file using UUID (before "not attached" check)
        if [[ -z "$vhd_path" ]]; then
            if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                local found_path
                found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
                
                if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                    vhd_path="$found_path"
                    log_debug "Found VHD path in tracking file: $vhd_path"
                fi
            fi
        fi
        
        if ! wsl_is_vhd_attached "$uuid"; then
            if [[ "$QUIET" == "true" ]]; then
                if [[ -n "$vhd_path" ]]; then
                    echo "$vhd_path ($uuid): not attached"
                else
                    echo "${uuid:-$dev_name}: not attached"
                fi
            else
                echo ""
                echo "VHD is not attached to WSL. Nothing to do."
            fi
            exit 0
        fi
        
        # Check if mounted and unmount first
        if wsl_is_vhd_mounted "$uuid"; then
            original_mount_point=$(wsl_get_vhd_mount_point "$uuid")
            was_mounted="Yes"
            log_debug "VHD is mounted at: $original_mount_point"
            
            if wsl_umount_vhd "$original_mount_point"; then
                tracking_file_remove_mount_point "$vhd_path" "$dev_name" "$uuid" "$original_mount_point" ""
            else
                error_exit "Failed to unmount VHD"
            fi
        fi
    else
        log_debug "Attempting path-based detach (mount status unknown)..."
    fi
    
    # Detach from WSL
    log_debug "Detaching VHD from WSL..."
    
    if [[ -n "$vhd_path" ]]; then
        local history_dev_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$vhd_path")
            history_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        
        if wsl_detach_vhd "$vhd_path" "$uuid" "$history_dev_name"; then
            tracking_file_save_detach_history "$vhd_path" "$uuid" "$history_dev_name"
            tracking_file_remove_mapping "$vhd_path"
        else
            error_exit "Failed to detach VHD from WSL"
        fi
    else
        local identifier="${dev_name:-$uuid}"
        local path_help="The VHD path could not be found automatically.

Please provide the path explicitly:
  $0 detach --dev-name $identifier --vhd-path <vhd_path>
  $0 detach --uuid $identifier --vhd-path <vhd_path>"
        error_exit "Could not determine VHD path" 1 "$path_help"
    fi
    
    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        local identifier="${dev_name:-$uuid}"
        if ! wsl_is_vhd_attached "$uuid" 2>/dev/null; then
            if [[ -n "$vhd_path" ]]; then
                echo "$vhd_path ($identifier): detached"
            else
                echo "$identifier: detached"
            fi
        else
            if [[ -n "$vhd_path" ]]; then
                echo "$vhd_path ($identifier): detach failed"
            else
                echo "$identifier: detach failed"
            fi
        fi
        return 0
    fi
    
    # Display result table
    print_table_title "VHD Detach Result"
    
    local kv_widths="16,50"
    print_table_header "$kv_widths" "Property" "Value"
    [[ -n "$vhd_path" ]] && print_table_row "$kv_widths" "Path" "$vhd_path"
    [[ -n "$uuid" ]] && print_table_row "$kv_widths" "UUID" "$uuid"
    [[ -n "$dev_name" ]] && print_table_row "$kv_widths" "Device" "/dev/$dev_name"
    [[ -n "$original_mount_point" ]] && print_table_row "$kv_widths" "Was Mounted At" "$original_mount_point"
    print_table_row "$kv_widths" "Unmounted" "$was_mounted"
    print_table_row "$kv_widths" "Status" "detached"
    print_table_footer "$kv_widths"
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
    
    log_debug "Delete operation starting"
    
    # Try to discover UUID if not provided
    if [[ -z "$uuid" ]]; then
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 2 ]]; then
            log_debug "Multiple VHDs attached - cannot verify if this VHD is attached"
            uuid=""
        elif [[ -n "$uuid" ]]; then
            log_debug "Discovered UUID from path: $uuid"
        fi
    fi
    
    # Check if VHD is currently attached
    if [[ -n "$uuid" ]] && wsl_is_vhd_attached "$uuid"; then
        log_debug "VHD is currently attached - attempting to detach..."
        
        if [[ -n "$vhd_path" ]]; then
            if bash "$0" -q umount --vhd-path "$vhd_path" >/dev/null 2>&1; then
                log_debug "VHD detached successfully"
                sleep 1
            else
                if wsl.exe --unmount "$vhd_path" >/dev/null 2>&1; then
                    log_debug "VHD detached successfully"
                    sleep 1
                else
                    local detach_help="The VHD must be unmounted and detached before deletion.
To unmount and detach, run:
  $0 umount --vhd-path $vhd_path"
                    error_exit "VHD is currently attached to WSL and could not be detached" 1 "$detach_help"
                fi
            fi
        else
            local detach_help="The VHD must be unmounted and detached before deletion.
To unmount and detach, run:
  $0 umount --uuid $uuid"
            error_exit "VHD is currently attached to WSL" 1 "$detach_help"
        fi
    fi
    
    # Confirmation prompt unless --force is used or YES flag is set
    if [[ "$force" == "false" ]] && [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
        echo ""
        echo "Delete VHD: $vhd_path"
        echo ""
        echo "WARNING: This operation cannot be undone!"
        echo -n "Are you sure you want to delete this VHD? (yes/no): "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            echo "Deletion cancelled."
            exit 0
        fi
    fi
    
    # Delete the VHD file
    log_debug "Deleting VHD file..."
    if wsl_delete_vhd "$vhd_path"; then
        tracking_file_remove_mapping "$vhd_path"
        
        # Quiet mode output
        if [[ "$QUIET" == "true" ]]; then
            echo "$vhd_path: deleted"
            return 0
        fi
        
        # Display result table
        print_table_title "VHD Delete Result"
        
        local kv_widths="16,50"
        print_table_header "$kv_widths" "Property" "Value"
        print_table_row "$kv_widths" "Path" "$vhd_path"
        [[ -n "$uuid" ]] && print_table_row "$kv_widths" "UUID" "$uuid"
        print_table_row "$kv_widths" "Status" "deleted"
        print_table_footer "$kv_widths"
    else
        error_exit "Failed to delete VHD"
    fi
    
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
    
    log_debug "Create operation starting"
    
    # Check if VHD already exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path")
    if [[ -e "$vhd_path_wsl" ]]; then
        if [[ "$force" == "false" ]]; then
            local exists_help="Use 'mount' command to attach the existing VHD, or use --force to overwrite"
            error_exit "VHD file already exists at $vhd_path" 1 "$exists_help"
        else
            # Force mode: handle existing VHD
            local existing_uuid
            local discovery_result
            existing_uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
            discovery_result=$?
            
            if [[ $discovery_result -eq 2 ]]; then
                local tracked_uuid=$(tracking_file_lookup_uuid_by_path "$vhd_path")
                if [[ -n "$tracked_uuid" ]] && wsl_is_vhd_attached "$tracked_uuid"; then
                    existing_uuid="$tracked_uuid"
                    discovery_result=0
                fi
            fi
            
            local needs_unmount=false
            if [[ $discovery_result -eq 0 && -n "$existing_uuid" ]] && wsl_is_vhd_attached "$existing_uuid"; then
                needs_unmount=true
            fi
            
            if [[ "$needs_unmount" == "true" ]]; then
                if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
                    echo ""
                    echo "VHD is currently attached. It must be unmounted before overwriting."
                    echo -n "Do you want to unmount it now? (yes/no): "
                    read -r unmount_confirmation
                    
                    if [[ "$unmount_confirmation" != "yes" ]]; then
                        echo "Operation cancelled."
                        exit 0
                    fi
                fi
                
                log_debug "Unmounting VHD..."
                
                if [[ $discovery_result -eq 0 && -n "$existing_uuid" ]]; then
                    if wsl_is_vhd_mounted "$existing_uuid"; then
                        local existing_mount_point=$(wsl_get_vhd_mount_point "$existing_uuid")
                        if [[ -n "$existing_mount_point" ]]; then
                            if ! wsl_umount_vhd "$existing_mount_point"; then
                                error_exit "Failed to unmount VHD from filesystem"
                            fi
                        fi
                    fi
                    
                    local existing_dev_name=""
                    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                        local normalized_path=$(normalize_vhd_path "$vhd_path")
                        existing_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
                    fi
                    wsl_detach_vhd "$vhd_path" "$existing_uuid" "$existing_dev_name" 2>/dev/null || true
                else
                    wsl.exe --unmount "$vhd_path" 2>/dev/null || true
                fi
                
                sleep 2
            fi
            
            if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
                echo ""
                echo "WARNING: This will permanently delete the existing VHD file!"
                echo -n "Are you sure you want to overwrite $vhd_path? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    echo "Operation cancelled."
                    exit 0
                fi
            fi
            
            log_debug "Deleting existing VHD file..."
            if ! rm -f "$vhd_path_wsl"; then
                error_exit "Failed to delete existing VHD"
            fi
        fi
    fi
    
    log_debug "Creating VHD: $vhd_path (size: $create_size)"
    
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
        log_debug "Creating directory: $vhd_dir"
        if ! debug_cmd mkdir -p "$vhd_dir" 2>/dev/null; then
            error_exit "Failed to create directory $vhd_dir"
        fi
    fi
    
    # Create the VHD file
    if ! debug_cmd qemu-img create -f vhdx "$vhd_path_wsl" "$create_size" >/dev/null 2>&1; then
        error_exit "Failed to create VHD file"
    fi
    
    log_debug "VHD file created successfully"
    
    # If --format option was provided, attach and format the VHD
    if [[ -n "$format_type" ]]; then
        log_debug "Formatting VHD with $format_type..."
        
        local old_devs=($(wsl_get_block_devices))
        log_debug "Captured old_devs array (count: ${#old_devs[@]}): ${old_devs[*]}"
        
        if ! wsl_attach_vhd "$vhd_path"; then
            error_exit "Failed to attach VHD to WSL for formatting"
        fi
        
        register_vhd_cleanup "$vhd_path" "" ""
        
        local dev_name
        dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
        
        if [[ -z "$dev_name" ]]; then
            error_exit "Failed to detect device of attached VHD"
        fi
        
        log_debug "Formatting device /dev/$dev_name with $format_type..."
        
        local uuid
        uuid=$(format_vhd "$dev_name" "$format_type")
        if [[ $? -ne 0 || -z "$uuid" ]]; then
            error_exit "Failed to format device /dev/$dev_name with $format_type"
        fi
        
        unregister_vhd_cleanup "$vhd_path"
        register_vhd_cleanup "$vhd_path" "$uuid" "$dev_name"
        
        tracking_file_save_mapping "$vhd_path" "$uuid" "" "$dev_name"
        log_debug "Saved tracking file mapping: $vhd_path → $uuid"
        
        log_debug "Detaching VHD..."
        if wsl_detach_vhd "$vhd_path" "$uuid" "$dev_name"; then
            tracking_file_save_detach_history "$vhd_path" "$uuid" "$dev_name"
            tracking_file_remove_mapping "$vhd_path"
        fi
        
        unregister_vhd_cleanup "$vhd_path"
        
        # Quiet mode output
        if [[ "$QUIET" == "true" ]]; then
            echo "$vhd_path: created,formatted with UUID=$uuid"
            return 0
        fi
        
        # Display result table
        print_table_title "VHD Create Result"
        
        local kv_widths="16,50"
        print_table_header "$kv_widths" "Property" "Value"
        print_table_row "$kv_widths" "Path" "$vhd_path"
        print_table_row "$kv_widths" "Size" "$create_size"
        print_table_row "$kv_widths" "Device" "/dev/$dev_name"
        print_table_row "$kv_widths" "UUID" "$uuid"
        print_table_row "$kv_widths" "Filesystem" "$format_type"
        print_table_row "$kv_widths" "Status" "created, formatted"
        print_table_footer "$kv_widths"
        
        echo ""
        echo "To use the VHD, run:"
        echo "  $0 mount --vhd-path $vhd_path --mount-point <mount_point>"
    else
        # No format option - display result table
        # Quiet mode output
        if [[ "$QUIET" == "true" ]]; then
            echo "$vhd_path: created"
            return 0
        fi
        
        print_table_title "VHD Create Result"
        
        local kv_widths="16,50"
        print_table_header "$kv_widths" "Property" "Value"
        print_table_row "$kv_widths" "Path" "$vhd_path"
        print_table_row "$kv_widths" "Size" "$create_size"
        print_table_row "$kv_widths" "Status" "created (not formatted)"
        print_table_footer "$kv_widths"
        
        echo ""
        echo "Next steps:"
        echo "  1. $0 attach --vhd-path $vhd_path"
        echo "  2. $0 format --dev-name <device_name> --type ext4"
        echo "  3. $0 mount --vhd-path $vhd_path --mount-point <mount_point>"
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
    
    log_debug "Resize operation starting"
    
    # Check if target mount point exists and is mounted
    if [[ ! -d "$target_mount_point" ]]; then
        error_exit "Target mount point does not exist: $target_mount_point"
    fi
    
    # Find UUID of target disk
    local target_uuid=$(wsl_find_uuid_by_mountpoint "$target_mount_point")
    if [[ -z "$target_uuid" ]]; then
        error_exit "No VHD mounted at $target_mount_point" 1 "Please ensure the target disk is mounted first"
    fi
    
    log_debug "Found target disk: $target_uuid at $target_mount_point"
    
    # Get target disk path by finding device and checking lsblk
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$target_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
    fi
    local target_device=$(lsblk -f -J | jq -r --arg UUID "$target_uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
    
    if [[ -z "$target_device" ]]; then
        error_exit "Could not find device for UUID $target_uuid"
    fi
    
    # Calculate total size of all files in target disk
    echo ""
    echo "Analyzing source VHD..."
    local target_size_bytes=$(get_directory_size_bytes "$target_mount_point")
    local target_size_human=$(bytes_to_human "$target_size_bytes")
    
    # Convert new_size to bytes
    local new_size_bytes=$(convert_size_to_bytes "$new_size")
    local required_size_bytes=$((target_size_bytes * 130 / 100))  # Add 30%
    local required_size_human=$(bytes_to_human "$required_size_bytes")
    
    # Determine actual size to use
    local actual_size_bytes=$new_size_bytes
    local actual_size_str="$new_size"
    
    if [[ $new_size_bytes -lt $required_size_bytes ]]; then
        echo "Note: Requested size ($new_size) smaller than required, using: $required_size_human"
        actual_size_bytes=$required_size_bytes
        actual_size_str=$required_size_human
    fi
    
    # Count files in target disk
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "find '$target_mount_point' -type f | wc -l"
    fi
    local target_file_count=$(find "$target_mount_point" -type f 2>/dev/null | wc -l)
    
    # We need to find the VHD path by looking it up from the tracking file using UUID
    local target_vhd_path=""
    local target_dev_name=""
    
    # Look up VHD path from tracking file using UUID
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} jq -r --arg uuid '$target_uuid' '.mappings[] | select(.uuid == \$uuid) | path(.) | .[-1]' $DISK_TRACKING_FILE" >&2
        fi
        local normalized_path=$(jq -r --arg uuid "$target_uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        
        if [[ -n "$normalized_path" && "$normalized_path" != "null" ]]; then
            target_vhd_path="$normalized_path"
            target_dev_name=$(jq -r --arg uuid "$target_uuid" "$JQ_GET_DEV_NAME_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        fi
    fi
    
    # If path lookup failed, try to infer from mount point name as fallback
    if [[ -z "$target_vhd_path" ]]; then
        target_dev_name=$(basename "$target_mount_point")
        local path_help="The VHD path is required for resize operation.
Please ensure the VHD was attached/mounted using vhdm.sh so it's tracked."
        error_exit "Cannot determine VHD path from tracking file" 1 "$path_help"
    fi
    
    log_debug "Target VHD path: $target_vhd_path"
    
    # Create new VHD with temporary name
    local target_vhd_dir=$(dirname "${target_vhd_path}")
    local target_vhd_basename=$(basename "$target_vhd_path" .vhdx)
    target_vhd_basename=$(basename "$target_vhd_basename" .vhd)
    local new_vhd_path="${target_vhd_dir}/${target_vhd_basename}_temp.vhdx"
    local temp_mount_point="${target_mount_point}_temp"
    
    echo "Creating temporary VHD..."
    
    # Create new VHD
    local new_uuid
    if new_uuid=$(wsl_create_vhd "$new_vhd_path" "$actual_size_str" "ext4" 2>&1); then
        log_debug "New VHD created: $new_uuid"
        register_vhd_cleanup "$new_vhd_path" "$new_uuid" ""
    else
        error_exit "Failed to create new VHD: $new_uuid"
    fi
    
    # Mount the new VHD
    log_debug "Mounting new VHD at $temp_mount_point..."
    if [[ ! -d "$temp_mount_point" ]]; then
        if ! create_mount_point "$temp_mount_point"; then
            error_exit "Failed to create temporary mount point"
        fi
    fi
    
    if ! wsl_mount_vhd "$new_uuid" "$temp_mount_point"; then
        error_exit "Failed to mount new VHD"
    fi
    
    # Copy all files from target disk to new disk
    echo "Copying files (this may take a while)..."
    
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "sudo rsync -a '$target_mount_point/' '$temp_mount_point/'"
    fi
    
    if ! check_sudo_permissions; then
        error_exit "Cannot copy files: sudo permissions required"
    fi
    
    if ! safe_sudo rsync -a "$target_mount_point/" "$temp_mount_point/" 2>&1; then
        error_exit "Failed to copy files"
    fi
    
    # Verify file count and size
    echo "Verifying data integrity..."
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "find '$temp_mount_point' -type f | wc -l"
    fi
    local new_file_count=$(find "$temp_mount_point" -type f 2>/dev/null | wc -l)
    local new_size_bytes_copy=$(get_directory_size_bytes "$temp_mount_point")
    local new_size_human=$(bytes_to_human "$new_size_bytes_copy")
    
    if [[ $new_file_count -ne $target_file_count ]]; then
        local mismatch_help="Expected: $target_file_count, Got: $new_file_count"
        error_exit "File count mismatch!" 1 "$mismatch_help"
    fi
    
    log_debug "Verification passed: $new_file_count files, $new_size_human"
    
    # Unmount and detach target disk
    echo "Swapping VHD files..."
    if ! wsl_umount_vhd "$target_mount_point"; then
        error_exit "Failed to unmount target disk"
    fi
    
    # Get device names from tracking file for history
    local target_dev_name_hist=""
    local new_dev_name=""
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        local normalized_target=$(normalize_vhd_path "$target_vhd_path")
        local normalized_new=$(normalize_vhd_path "$new_vhd_path")
        target_dev_name_hist=$(jq -r --arg path "$normalized_target" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        new_dev_name=$(jq -r --arg path "$normalized_new" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
    fi
    
    if ! wsl_detach_vhd "$target_vhd_path" "$target_uuid" "$target_dev_name_hist"; then
        error_exit "Failed to detach target disk"
    fi
    
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
    
    log_debug "mv '$target_vhd_path_wsl' '$backup_vhd_path_wsl'"
    
    if ! mv "$target_vhd_path_wsl" "$backup_vhd_path_wsl" 2>/dev/null; then
        error_exit "Failed to rename target VHD"
    fi
    
    # Unmount new disk temporarily
    if ! wsl_umount_vhd "$temp_mount_point"; then
        error_exit "Failed to unmount new disk"
    fi
    
    if ! wsl_detach_vhd "$new_vhd_path" "$new_uuid" "$new_dev_name"; then
        error_exit "Failed to detach new disk"
    fi
    
    unregister_vhd_cleanup "$new_vhd_path" 2>/dev/null || true
    
    # Rename new VHD to target name
    local new_vhd_path_wsl
    new_vhd_path_wsl=$(wsl_convert_path "$new_vhd_path")
    
    log_debug "mv '$new_vhd_path_wsl' '$target_vhd_path_wsl'"
    
    if ! mv "$new_vhd_path_wsl" "$target_vhd_path_wsl" 2>/dev/null; then
        error_exit "Failed to rename new VHD"
    fi
    
    # Mount the renamed VHD
    echo "Mounting resized VHD..."
    
    local old_devs=($(wsl_get_block_devices))
    
    if ! wsl_attach_vhd "$target_vhd_path"; then
        error_exit "Failed to attach resized VHD"
    fi
    
    local final_dev_name
    final_dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
    
    if [[ -z "$final_dev_name" ]]; then
        error_exit "Failed to detect device of resized VHD"
    fi
    
    local final_uuid
    final_uuid=$(wsl_get_uuid_by_device "$final_dev_name")
    
    if [[ -z "$final_uuid" ]]; then
        error_exit "Failed to detect UUID of resized VHD (device: /dev/$final_dev_name)"
    fi
    
    if wsl_mount_vhd "$final_uuid" "$target_mount_point"; then
        if [[ "$new_vhd_path" != "$target_vhd_path" ]]; then
            tracking_file_remove_mapping "$new_vhd_path" 2>/dev/null || true
        fi
        tracking_file_save_mapping "$target_vhd_path" "$final_uuid" "$target_mount_point" "$final_dev_name"
        tracking_file_remove_detach_history "$target_vhd_path"
        unregister_vhd_cleanup "$target_vhd_path" 2>/dev/null || true
    else
        error_exit "Failed to mount resized VHD"
    fi
    
    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        echo "$target_vhd_path: resized to $actual_size_str with UUID=$final_uuid"
        return 0
    fi
    
    # Display result table
    print_table_title "VHD Resize Result"
    
    local kv_widths="18,50"
    print_table_header "$kv_widths" "Property" "Value"
    print_table_row "$kv_widths" "Path" "$target_vhd_path"
    print_table_row "$kv_widths" "New UUID" "$final_uuid"
    print_table_row "$kv_widths" "Device" "/dev/$final_dev_name"
    print_table_row "$kv_widths" "Mount Point" "$target_mount_point"
    print_table_row "$kv_widths" "New Size" "$actual_size_str"
    print_table_row "$kv_widths" "Files" "$new_file_count"
    print_table_row "$kv_widths" "Data Size" "$new_size_human"
    print_table_row "$kv_widths" "Backup" "$backup_vhd_path_wsl"
    print_table_row "$kv_widths" "Status" "resized"
    print_table_footer "$kv_widths"
    
    echo ""
    echo "Note: You can delete the backup once you verify the resized disk."
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
    
    log_debug "Format operation starting"
    
    local target_identifier=""
    
    # Determine device name based on provided arguments
    if [[ -n "$uuid" ]]; then
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
        fi
        dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        
        if [[ -z "$dev_name" ]]; then
            local uuid_help="The UUID might be incorrect or the VHD is not attached.
To find attached VHDs, run: $0 status --all"
            error_exit "No device found with UUID: $uuid" 1 "$uuid_help"
        fi
        
        if ! validate_device_name "$dev_name"; then
            local device_help="Device name must match pattern: sd[a-z]+ (e.g., sdd, sde, sdaa)"
            error_exit "Invalid device name format: $dev_name" 1 "$device_help"
        fi
        
        if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
            echo ""
            echo "WARNING: Device /dev/$dev_name is already formatted (UUID: $uuid)"
            echo "Formatting will destroy all existing data and generate a new UUID."
            echo -n "Are you sure you want to format /dev/$dev_name? (yes/no): "
            read -r confirmation
            
            if [[ "$confirmation" != "yes" ]]; then
                echo "Format operation cancelled."
                exit 0
            fi
        fi
        
        target_identifier="UUID $uuid"
        old_uuid="$uuid"
    else
        target_identifier="device name $dev_name"
        
        if [[ ! -b "/dev/$dev_name" ]]; then
            local device_help="Please check the device name is correct.
To find attached VHDs, run: $0 status --all"
            error_exit "Block device /dev/$dev_name does not exist" 1 "$device_help"
        fi
        
        local existing_uuid
        existing_uuid=$(safe_sudo_capture blkid -s UUID -o value "/dev/$dev_name" 2>/dev/null)
        if [[ -n "$existing_uuid" ]]; then
            if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
                echo ""
                echo "WARNING: Device /dev/$dev_name is already formatted (UUID: $existing_uuid)"
                echo "Formatting will destroy all existing data and generate a new UUID."
                echo -n "Are you sure you want to format /dev/$dev_name? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    echo "Format operation cancelled."
                    exit 0
                fi
            fi
        fi
    fi
    
    log_debug "Formatting device /dev/$dev_name with $format_type..."
    
    # Format using helper function
    local new_uuid=$(format_vhd "$dev_name" "$format_type")
    if [[ $? -ne 0 || -z "$new_uuid" ]]; then
        error_exit "Failed to format device /dev/$dev_name"
    fi
    
    # Try to update tracking file with new UUID
    local tracked_path=""
    
    if [[ -n "$old_uuid" ]]; then
        tracked_path=$(tracking_file_lookup_path_by_uuid "$old_uuid")
        if [[ -n "$tracked_path" ]]; then
            log_debug "Found tracked path by old UUID: $tracked_path"
        fi
    fi
    
    if [[ -z "$tracked_path" ]]; then
        tracked_path=$(tracking_file_lookup_path_by_dev_name "$dev_name")
        if [[ -n "$tracked_path" ]]; then
            log_debug "Found tracked path by device name: $tracked_path"
        fi
    fi
    
    if [[ -n "$tracked_path" ]]; then
        tracking_file_save_mapping "$tracked_path" "$new_uuid" "" "$dev_name"
        log_debug "Updated tracking file: $tracked_path → $new_uuid"
    fi
    
    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        if [[ -n "$tracked_path" ]]; then
            echo "$tracked_path (/dev/$dev_name): formatted with UUID=$new_uuid"
        else
            echo "/dev/$dev_name: formatted with UUID=$new_uuid"
        fi
        return 0
    fi
    
    # Display result table
    print_table_title "VHD Format Result"
    
    local kv_widths="16,50"
    print_table_header "$kv_widths" "Property" "Value"
    print_table_row "$kv_widths" "Device" "/dev/$dev_name"
    print_table_row "$kv_widths" "New UUID" "$new_uuid"
    print_table_row "$kv_widths" "Filesystem" "$format_type"
    [[ -n "$tracked_path" ]] && print_table_row "$kv_widths" "VHD Path" "$tracked_path"
    print_table_row "$kv_widths" "Status" "formatted"
    print_table_footer "$kv_widths"
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
    
    log_debug "Attaching VHD: $vhd_path"
    
    # Take snapshot of current block devices before attaching
    local old_devs=($(wsl_get_block_devices))
    log_debug "Captured old_devs array (count: ${#old_devs[@]}): ${old_devs[*]}"
    
    # Try to attach the VHD
    local uuid=""
    local dev_name=""
    local script_name="${0##*/}"
    local attach_status="newly attached"
    local is_formatted="Yes"
    
    if wsl_attach_vhd "$vhd_path" 2>/dev/null; then
        # Register VHD for cleanup (will be unregistered on successful completion)
        register_vhd_cleanup "$vhd_path" "" ""
        
        # Detect new device using snapshot-based detection
        dev_name=$(detect_new_device_after_attach "" "${old_devs[@]}")
        
        if [[ -n "$dev_name" ]]; then
            uuid=$(wsl_get_uuid_by_device "$dev_name")
            
            if [[ -n "$uuid" ]]; then
                tracking_file_save_mapping "$vhd_path" "$uuid" "" "$dev_name"
                tracking_file_remove_detach_history "$vhd_path"
            else
                is_formatted="No"
                tracking_file_save_mapping "$vhd_path" "" "" "$dev_name"
                tracking_file_remove_detach_history "$vhd_path"
            fi
            
            unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
        else
            dev_name="(detection failed)"
        fi
    else
        # Attachment failed - VHD might already be attached
        log_debug "VHD attachment failed - checking if already attached..."
        
        local discovery_result
        uuid=$(wsl_find_uuid_by_path "$vhd_path" 2>&1)
        discovery_result=$?
        
        handle_uuid_discovery_result "$discovery_result" "$uuid" "attach" "$vhd_path"
        
        if wsl_is_vhd_attached "$uuid"; then
            attach_status="already attached"
            
            if [[ "$DEBUG" == "true" ]]; then
                log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
            fi
            dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            
            tracking_file_save_mapping "$vhd_path" "$uuid" "" "$dev_name"
            tracking_file_remove_detach_history "$vhd_path"
            unregister_vhd_cleanup "$vhd_path" 2>/dev/null || true
        else
            local attach_help="The VHD might already be attached with a different name or path.
Try running: ./vhdm.sh status --all"
            error_exit "Failed to attach VHD" 1 "$attach_help"
        fi
    fi
    
    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        if [[ -n "$uuid" ]]; then
            echo "$vhd_path ($uuid): attached"
        else
            echo "$vhd_path: attached (UUID unknown)"
        fi
        return 0
    fi
    
    # Display result table
    print_table_title "VHD Attach Result"
    
    local kv_widths="16,50"
    print_table_header "$kv_widths" "Property" "Value"
    print_table_row "$kv_widths" "Path" "$vhd_path"
    print_table_row "$kv_widths" "Status" "$attach_status"
    [[ -n "$dev_name" && "$dev_name" != "(detection failed)" ]] && print_table_row "$kv_widths" "Device" "/dev/$dev_name"
    [[ -n "$uuid" ]] && print_table_row "$kv_widths" "UUID" "$uuid"
    print_table_row "$kv_widths" "Formatted" "$is_formatted"
    print_table_footer "$kv_widths"
    
    # Show warning for unformatted VHD
    if [[ "$is_formatted" == "No" ]]; then
        echo ""
        echo "Note: VHD is not formatted. To format, run:"
        echo "  $0 format --dev-name $dev_name --type ext4"
    fi
    
    # Show warning if device detection failed
    if [[ "$dev_name" == "(detection failed)" ]]; then
        echo ""
        echo "Note: Device detection failed. Find device using:"
        echo "  $0 status --all"
    fi
}

# Function to show VHD tracking history (mappings + detach history)
# Arguments:
#   --limit N                Number of detach events to show [default: 10, max: 50]
#   --vhd-path PATH           Show info for specific VHD path
#
# Logic Flow:
# ===========
# 1. Validate command arguments
# 2. If path provided: show mapping + detach history for that path
# 3. If no path: show all mappings + recent detach history
# 4. Report success or error
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
    
    # Sync tracking file before displaying (ensure accurate data)
    # Note: mappings are already synced on startup via auto-sync
    # Here we also clean up detach_history entries for non-existent VHD files
    tracking_file_cleanup_stale_mappings >/dev/null 2>&1
    tracking_file_cleanup_stale_detach_history >/dev/null 2>&1
    
    log_debug "Displaying VHD tracking history"
    
    if [[ -n "$show_path" ]]; then
        # Show info for specific path
        local normalized_path=$(normalize_vhd_path "$show_path")
        
        # Check if path is in current mappings (attached)
        local mapping_json=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            mapping_json=$(jq -r --arg path "$normalized_path" '.mappings[$path] // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        
        print_table_title "VHD History: $show_path"
        
        if [[ -n "$mapping_json" && "$mapping_json" != "null" && "$mapping_json" != "" ]]; then
            if [[ "$QUIET" == "true" ]]; then
                echo "{\"mapping\": $mapping_json}"
            else
                local uuid=$(echo "$mapping_json" | jq -r '.uuid // empty')
                local dev_name=$(echo "$mapping_json" | jq -r '.dev_name // empty')
                local mount_points=$(echo "$mapping_json" | jq -r '.mount_points // empty')
                local last_attached=$(echo "$mapping_json" | jq -r '.last_attached // empty')
                
                echo "Current Status: Attached"
                echo ""
                
                # Key-value table for current mapping
                local kv_widths="16,50"
                print_table_header "$kv_widths" "Property" "Value"
                print_table_row "$kv_widths" "Path" "$normalized_path"
                [[ -n "$uuid" && "$uuid" != "null" ]] && print_table_row "$kv_widths" "UUID" "$uuid"
                [[ -n "$dev_name" && "$dev_name" != "null" ]] && print_table_row "$kv_widths" "Device" "/dev/$dev_name"
                [[ -n "$mount_points" && "$mount_points" != "null" ]] && print_table_row "$kv_widths" "Mount Points" "$mount_points"
                [[ -n "$last_attached" && "$last_attached" != "null" ]] && print_table_row "$kv_widths" "Last Attached" "$last_attached"
                print_table_footer "$kv_widths"
            fi
        else
            echo "Current Status: Not attached"
        fi
        
        # Show detach history for this path
        local history_json=$(tracking_file_get_last_detach_for_path "$show_path")
        
        if [[ -n "$history_json" ]]; then
            print_table_title "Last Detach Event"
            if [[ "$QUIET" == "true" ]]; then
                echo "{\"detach_history\": $history_json}"
            else
                local uuid=$(echo "$history_json" | jq -r '.uuid')
                local dev_name=$(echo "$history_json" | jq -r '.dev_name // empty')
                local timestamp=$(echo "$history_json" | jq -r '.timestamp')
                
                local kv_widths="16,50"
                print_table_header "$kv_widths" "Property" "Value"
                print_table_row "$kv_widths" "UUID" "$uuid"
                [[ -n "$dev_name" && "$dev_name" != "null" && "$dev_name" != "" ]] && print_table_row "$kv_widths" "Device" "/dev/$dev_name"
                print_table_row "$kv_widths" "Detached" "$timestamp"
                print_table_footer "$kv_widths"
            fi
        else
            echo ""
            echo "No detach history for this path"
        fi
    else
        # ---- Section 1: Current Mappings ----
        local mappings_json=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            mappings_json=$(jq -r '.mappings // {}' "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        
        local mapping_count=0
        if [[ -n "$mappings_json" && "$mappings_json" != "{}" ]]; then
            mapping_count=$(echo "$mappings_json" | jq 'keys | length')
        fi
        
        print_table_title "Current Mappings (Attached VHDs)"
        
        if [[ "$QUIET" == "true" ]]; then
            echo "{\"mappings\": $mappings_json,"
        else
            if [[ $mapping_count -eq 0 ]]; then
                echo "No VHDs currently tracked as attached"
            else
                # Table format: Path(40), UUID(36), Device(8), Mount Points(25)
                local col_widths="40,36,8,25"
                print_table_header "$col_widths" "Path" "UUID" "Device" "Mount Points"
                
                # Iterate through mappings
                while IFS= read -r path; do
                    local m_uuid=$(echo "$mappings_json" | jq -r --arg p "$path" '.[$p].uuid // "-"')
                    local m_dev=$(echo "$mappings_json" | jq -r --arg p "$path" '.[$p].dev_name // "-"')
                    local m_mounts=$(echo "$mappings_json" | jq -r --arg p "$path" '.[$p].mount_points // "-"')
                    
                    [[ "$m_uuid" == "null" ]] && m_uuid="-"
                    [[ "$m_dev" == "null" ]] && m_dev="-"
                    [[ "$m_mounts" == "null" ]] && m_mounts="-"
                    
                    print_table_row "$col_widths" "$path" "$m_uuid" "$m_dev" "$m_mounts"
                done < <(echo "$mappings_json" | jq -r 'keys[]')
                
                print_table_footer "$col_widths"
            fi
        fi
        
        # ---- Section 2: Detach History ----
        local history_json=$(tracking_file_get_detach_history "$limit")
        
        print_table_title "Detach History (last $limit events)"
        
        if [[ "$QUIET" == "true" ]]; then
            echo "\"detach_history\": $history_json}"
        else
            local count=$(echo "$history_json" | jq 'length')
            
            if [[ "$count" -eq 0 ]]; then
                echo "No detach history available"
            else
                # Table format: Timestamp(20), Path(40), UUID(36)
                local col_widths="20,40,36"
                print_table_header "$col_widths" "Timestamp" "Path" "UUID"
                
                # Iterate through history
                while IFS= read -r entry; do
                    local h_timestamp=$(echo "$entry" | jq -r '.timestamp // "-"')
                    local h_path=$(echo "$entry" | jq -r '.path // "-"')
                    local h_uuid=$(echo "$entry" | jq -r '.uuid // "-"')
                    
                    print_table_row "$col_widths" "$h_timestamp" "$h_path" "$h_uuid"
                done < <(echo "$history_json" | jq -c '.[]')
                
                print_table_footer "$col_widths"
            fi
        fi
    fi
}

# ============================================================================
# SYNC COMMAND - Synchronize tracking file with actual system state
# ============================================================================
# Purpose: Ensure tracking file accurately reflects the current system state:
#   1. Remove mappings for VHDs that are no longer attached to WSL
#   2. Remove detach_history entries for VHD files that no longer exist
# This is a maintenance/cleanup operation that should be run periodically
# or when the tracking file may be out of sync with the actual system state.
#
# Usage: vhdm.sh sync [OPTIONS]
#   --dry-run    Show what would be removed without making changes
#
# Exit: 0 on success, 1 on error
sync_vhd() {
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                error_exit "Unknown sync option '$1'" 1 "Usage: $0 sync [--dry-run]"
                ;;
        esac
    done
    
    log_debug "Synchronizing tracking file"
    
    if [[ "$dry_run" == "true" ]]; then
        print_table_title "Sync Tracking File (DRY RUN)"
    else
        print_table_title "Sync Tracking File"
    fi
    
    # Check if tracking file exists
    if [[ ! -f "$DISK_TRACKING_FILE" ]]; then
        echo "No tracking file found. Nothing to synchronize."
        exit 0
    fi
    
    local total_removed=0
    local mappings_to_remove=()
    local history_to_remove=()
    
    # ---- Step 1: Collect stale mappings ----
    local paths
    paths=$(tracking_file_get_all_mapping_paths 2>/dev/null)
    
    local mapping_count=0
    
    if [[ -n "$paths" ]]; then
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            ((mapping_count++))
            
            local uuid
            uuid=$(tracking_file_get_uuid_for_path "$path")
            
            local should_remove=false
            local remove_reason=""
            
            if [[ -n "$uuid" && "$uuid" != "null" ]]; then
                if ! wsl_is_vhd_attached "$uuid" 2>/dev/null; then
                    should_remove=true
                    remove_reason="Not attached"
                fi
            else
                local vhd_path_wsl
                vhd_path_wsl=$(wsl_convert_path "$path" 2>/dev/null)
                if [[ -n "$vhd_path_wsl" && ! -e "$vhd_path_wsl" ]]; then
                    should_remove=true
                    remove_reason="File not found"
                fi
            fi
            
            if [[ "$should_remove" == "true" ]]; then
                mappings_to_remove+=("$path|$remove_reason")
            fi
        done <<< "$paths"
    fi
    
    # ---- Step 2: Collect stale history entries ----
    local history_paths
    history_paths=$(jq -r '.detach_history // [] | .[].path' "$DISK_TRACKING_FILE" 2>/dev/null | sort -u)
    
    local history_count=0
    
    if [[ -n "$history_paths" ]]; then
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            ((history_count++))
            
            local vhd_path_wsl
            vhd_path_wsl=$(wsl_convert_path "$path" 2>/dev/null)
            
            if [[ -n "$vhd_path_wsl" && ! -e "$vhd_path_wsl" ]]; then
                history_to_remove+=("$path")
            fi
        done <<< "$history_paths"
    fi
    
    # ---- Display stale mappings table ----
    if [[ ${#mappings_to_remove[@]} -gt 0 ]]; then
        local action_word="Removing"
        [[ "$dry_run" == "true" ]] && action_word="Would remove"
        
        echo "Stale Mappings ($action_word)"
        echo ""
        
        local col_widths="50,20"
        print_table_header "$col_widths" "Path" "Reason"
        
        for entry in "${mappings_to_remove[@]}"; do
            local m_path="${entry%%|*}"
            local m_reason="${entry##*|}"
            print_table_row "$col_widths" "$m_path" "$m_reason"
        done
        
        print_table_footer "$col_widths"
        echo ""
    fi
    
    # ---- Display stale history table ----
    if [[ ${#history_to_remove[@]} -gt 0 ]]; then
        local action_word="Removing"
        [[ "$dry_run" == "true" ]] && action_word="Would remove"
        
        echo "Stale History Entries ($action_word)"
        echo ""
        
        local col_widths="50,20"
        print_table_header "$col_widths" "Path" "Reason"
        
        for path in "${history_to_remove[@]}"; do
            print_table_row "$col_widths" "$path" "File not found"
        done
        
        print_table_footer "$col_widths"
        echo ""
    fi
    
    # ---- Actually remove entries (unless dry run) ----
    local mappings_removed=0
    local history_removed=0
    
    if [[ "$dry_run" == "false" ]]; then
        for entry in "${mappings_to_remove[@]}"; do
            local m_path="${entry%%|*}"
            if tracking_file_remove_mapping "$m_path"; then
                ((mappings_removed++))
            fi
        done
        
        for path in "${history_to_remove[@]}"; do
            if tracking_file_remove_detach_history "$path"; then
                ((history_removed++))
            fi
        done
    else
        mappings_removed=${#mappings_to_remove[@]}
        history_removed=${#history_to_remove[@]}
    fi
    
    total_removed=$((mappings_removed + history_removed))
    
    # ---- Summary table ----
    echo ""
    echo "Sync Summary"
    echo ""
    
    local kv_widths="25,15"
    print_table_header "$kv_widths" "Category" "Count"
    print_table_row "$kv_widths" "Mappings checked" "$mapping_count"
    print_table_row "$kv_widths" "Mappings removed" "$mappings_removed"
    print_table_row "$kv_widths" "History paths checked" "$history_count"
    print_table_row "$kv_widths" "History entries removed" "$history_removed"
    print_table_footer "$kv_widths"
    
    echo ""
    if [[ "$dry_run" == "true" ]]; then
        if [[ $total_removed -gt 0 ]]; then
            echo "DRY RUN: Would remove $total_removed total entries"
            echo "Run without --dry-run to apply changes"
        else
            echo "Tracking file is already in sync"
        fi
    else
        if [[ $total_removed -gt 0 ]]; then
            echo "Synchronization complete: removed $total_removed entries"
        else
            echo "Tracking file is already in sync"
        fi
    fi
    
    # Quiet mode output
    if [[ "$QUIET" == "true" ]]; then
        echo "mappings_removed:$mappings_removed history_removed:$history_removed"
    fi
}

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
        attach|format|mount|umount|unmount|detach|status|create|delete|resize|history|sync)
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
    sync)
        sync_vhd "$@"  # Pass remaining arguments to sync_vhd
        ;;
    *)
        echo -e "${RED}Error: No command specified${NC}"
        echo
        show_usage
        ;;
esac

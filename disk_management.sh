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
source "$ORIGINAL_SCRIPT_DIR/libs/wsl_helpers.sh"
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
    echo "  --path PATH              - [mandatory] VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    local default_name="${DEFAULT_VHD_NAME:-disk}"
    echo "  --name NAME              - [optional] VHD name for WSL attachment [default: $default_name]"
    echo "  Note: Attaches VHD to WSL without mounting to filesystem."
    echo "        VHD will be accessible as a block device (/dev/sdX) after attachment."
    echo
    echo "Format Command Options:"
    echo "  --name NAME              - [optional] VHD device block name (e.g., sdd, sde)"
    echo "  --uuid UUID              - [optional] VHD UUID"
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    echo "  --type TYPE              - [optional] Filesystem type (ext4, ext3, xfs, etc.) [default: $default_fs]"
    echo "  Note: Either --uuid or --name must be provided."
    echo "        VHD must be attached before formatting. Use 'attach' command first."
    echo "        If --uuid is provided for an already-formatted disk, confirmation will be required."
    echo
    echo "Mount Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format)"
    echo "  --mount-point PATH       - [mandatory] Mount point path"
    echo "  --name NAME              - [optional] VHD name for WSL attachment"
    echo "  Note: VHD must be formatted before mounting. Use 'format' command if needed."
    echo
    echo "Umount Command Options:"
    echo "  --path PATH              - [optional] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path or mount-point)"
    echo "  --mount-point PATH       - [optional] Mount point path (UUID will be discovered)"
    echo "  Note: Provide at least one option. UUID will be auto-discovered when possible."
    echo
    echo "Detach Command Options:"
    echo "  --uuid UUID              - [mandatory] VHD UUID to detach"
    echo "  --path PATH              - [optional] VHD file path (improves reliability)"
    echo "  Note: If VHD is mounted, it will be unmounted first."
    echo
    echo "Status Command Options:"
    echo "  --path PATH              - [optional] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path, name, or mount-point)"
    echo "  --name NAME              - [optional] VHD name (UUID will be discovered from tracking file)"
    echo "  --mount-point PATH       - [optional] Mount point path (UUID will be discovered)"
    echo "  --all                    - [optional] Show all attached VHDs"
    echo
    echo "Create Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    local default_size="${DEFAULT_VHD_SIZE:-1G}"
    echo "  --size SIZE              - [optional] VHD size (e.g., 1G, 500M, 10G) [default: $default_size]"
    echo "  --force                  - [optional] Overwrite existing VHD (auto-unmounts if attached, prompts for confirmation)"
    echo "  Note: Creates VHD file only. Use 'attach' or 'mount' commands to attach and use the disk."
    echo
    echo "Delete Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format, UUID will be discovered)"
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
    echo "  --path PATH              - [optional] Show last detach event for specific VHD path"
    echo "  Note: Shows detach history with timestamps, UUIDs, and VHD names."
    echo
    echo "Examples:"
    echo "  $0 attach --path C:/VMs/disk.vhdx --name mydisk"
    echo "  $0 format --name sdd --type ext4"
    echo "  $0 format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4"
    echo "  $0 mount --path C:/VMs/disk.vhdx --mount-point /mnt/data"
    echo "  $0 umount --path C:/VMs/disk.vhdx"
    echo "  $0 umount --mount-point /mnt/data"
    echo "  $0 umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
    echo "  $0 detach --uuid 72a3165c-f1be-4497-a1fb-2c55054ac472"
    echo "  $0 status --path C:/VMs/disk.vhdx"
    echo "  $0 status --name mydisk"
    echo "  $0 status --all"
    echo "  $0 create --path C:/VMs/disk.vhdx --size 5G"
    echo "  $0 delete --path C:/VMs/disk.vhdx"
    echo "  $0 delete --path C:/VMs/disk.vhdx --force"
    echo "  $0 resize --mount-point /mnt/data --size 10G"
    echo "  $0 history"
    echo "  $0 history --limit 20"
    echo "  $0 history --path C:/VMs/disk.vhdx"
    echo "  $0 -q status --all"
    echo
    exit 0
}

# Function to show status
show_status() {
    # Parse status command arguments
    local status_path=""
    local status_uuid=""
    local status_name=""
    local status_mount_point=""
    local show_all=false
    
    # If no arguments, show help
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 status [OPTIONS]"
        echo
        echo "Options:"
        echo "  --path PATH         Show status for specific VHD path (UUID auto-discovered)"
        echo "  --uuid UUID         Show status for specific UUID"
        echo "  --name NAME         Show status for specific VHD name (UUID auto-discovered)"
        echo "  --mount-point PATH  Show status for specific mount point (UUID auto-discovered)"
        echo "  --all               Show all attached VHDs"
        echo
        echo "Examples:"
        echo "  $0 status --all"
        echo "  $0 status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
        echo "  $0 status --path C:/VMs/disk.vhdx"
        echo "  $0 status --name mydisk"
        echo "  $0 status --mount-point /mnt/data"
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                status_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                status_uuid="$2"
                shift 2
                ;;
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--name requires a value"
                fi
                if ! validate_vhd_name "$2"; then
                    error_exit "Invalid VHD name format: $2" 1 "VHD name must contain only alphanumeric characters, hyphens, and underscores"
                fi
                status_name="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--mount-point requires a value"
                fi
                if ! validate_mount_point "$2"; then
                    error_exit "Invalid mount point format: $2" 1 "Mount point must be an absolute path (e.g., /mnt/data)"
                fi
                status_mount_point="$2"
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
    if [[ -z "$status_uuid" ]]; then
        # If name is provided, lookup UUID from tracking file
        if [[ -n "$status_name" ]]; then
            status_uuid=$(lookup_vhd_uuid_by_name "$status_name")
            
            if [[ -z "$status_uuid" ]]; then
                local name_help="VHD with name '$status_name' is not tracked.

Suggestions:
  1. Check the name is correct (case-sensitive)
  2. VHD might be attached with a different name
  3. See all attached VHDs: $0 status --all"
                if [[ "$QUIET" == "true" ]]; then
                    echo "not found"
                fi
                error_exit "VHD name not found in tracking file" 1 "$name_help"
            fi
            
            # Verify the UUID is actually attached
            if ! wsl_is_vhd_attached "$status_uuid"; then
                local stale_help="VHD with name '$status_name' (UUID: $status_uuid) is not attached.
The tracking file may be stale."
                if [[ "$QUIET" == "true" ]]; then
                    echo "not attached"
                fi
                error_exit "VHD found in tracking but not currently attached" 1 "$stale_help"
            fi
            
            log_info "Discovered UUID from name '$status_name': $status_uuid"
            log_info ""
        # If path is provided, check if VHD file exists first
        elif [[ -n "$status_path" ]]; then
            local vhd_path_wsl
            vhd_path_wsl=$(wsl_convert_path "$status_path")
            
            if [[ ! -e "$vhd_path_wsl" ]]; then
                local file_not_found_help="VHD file does not exist at: $status_path
  (WSL path: $vhd_path_wsl)

Suggestions:
  1. Check the file path is correct
  2. Create a new VHD: $0 create --path $status_path --size <size>
  3. See all attached VHDs: $0 status --all"
                if [[ "$QUIET" == "true" ]]; then
                    echo "not found"
                fi
                error_exit "VHD file not found" 1 "$file_not_found_help"
            fi
            
            # File exists, try to find UUID by path with multi-VHD safety
            local discovery_result
            status_uuid=$(wsl_find_uuid_by_path "$status_path" 2>&1)
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
            elif [[ -n "$status_uuid" ]]; then
                log_info "Found VHD UUID: $status_uuid"
                log_info ""
            fi
        # Try to find UUID by mount point if provided
        elif [[ -n "$status_mount_point" ]]; then
            status_uuid=$(wsl_find_uuid_by_mountpoint "$status_mount_point")
            if [[ -n "$status_uuid" ]]; then
                log_info "Found UUID by mount point: $status_uuid"
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
        log_info "      Use 'status --path <path>' to verify a specific VHD."
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
    if [[ -z "$status_uuid" ]]; then
        local suggestions=""
        if [[ -n "$status_mount_point" ]]; then
            suggestions="No VHD is currently mounted at: $status_mount_point

Suggestions:
  1. Check if the mount point exists: ls -ld $status_mount_point
  2. Verify VHD is mounted: mount | grep $status_mount_point
  3. See all attached VHDs: $0 status --all
  4. Mount the VHD first: $0 mount --path <path> --mount-point $status_mount_point"
        elif [[ -n "$status_path" ]]; then
            # Convert to WSL path to check if file exists
            local vhd_path_wsl
            vhd_path_wsl=$(wsl_convert_path "$status_path")
            
            if [[ ! -e "$vhd_path_wsl" ]]; then
                suggestions="VHD file not found at: $status_path

Suggestions:
  1. Check the file path is correct
  2. Create a new VHD: $0 create --path $status_path"
            else
                suggestions="VHD file exists at: $status_path
But it is not currently attached to WSL.

Suggestions:
  1. Mount the VHD: $0 mount --path $status_path
  2. See all attached VHDs: $0 status --all"
            fi
        else
            suggestions="No UUID, path, or mount point specified.

Suggestions:
  1. Provide a UUID: $0 status --uuid <uuid>
  2. Provide a path: $0 status --path <path>
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
    if [[ -n "$status_path" ]]; then
        log_info "  Path: $status_path"
    else
        log_info "  Path: Unknown (use --path to query by path)"
    fi
    [[ -n "$status_uuid" ]] && log_info "  UUID: $status_uuid"
    [[ -n "$status_mount_point" ]] && log_info "  Mount Point: $status_mount_point"
    log_info ""
    
    if wsl_is_vhd_attached "$status_uuid"; then
        log_success "VHD is attached to WSL"
        log_info ""
        [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$status_uuid"
        log_info ""
        
        if wsl_is_vhd_mounted "$status_uuid"; then
            log_success "VHD is mounted"
            [[ "$QUIET" == "true" ]] && echo "$status_path ($status_uuid): attached,mounted"
        else
            log_warn "VHD is attached but not mounted"
            [[ "$QUIET" == "true" ]] && echo "$status_path ($status_uuid): attached"
        fi
    else
        log_error "VHD not found"
        log_info "The VHD with UUID $status_uuid is not currently in WSL."
        [[ "$QUIET" == "true" ]] && echo "$status_path ($status_uuid): not found"
    fi
    log_info "========================================"
}

# Function to mount VHD
mount_vhd() {
    # Parse mount command arguments
    local mount_path=""
    local mount_point=""
    local default_name="${DEFAULT_VHD_NAME:-disk}"
    local mount_name="$default_name"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                mount_path="$2"
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
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--name requires a value"
                fi
                if ! validate_vhd_name "$2"; then
                    error_exit "Invalid VHD name format: $2" 1 "VHD name must contain only alphanumeric characters, hyphens, and underscores"
                fi
                mount_name="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown mount option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$mount_path" ]]; then
        error_exit "--path parameter is required" 1 "Usage: $0 mount --path PATH --mount-point MOUNT_POINT [--name NAME]"
    fi
    
    if [[ -z "$mount_point" ]]; then
        error_exit "--mount-point parameter is required" 1 "Usage: $0 mount --path PATH --mount-point MOUNT_POINT [--name NAME]"
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$mount_path")
    if [[ ! -e "$vhd_path_wsl" ]]; then
        error_exit "VHD file does not exist at $mount_path"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Mount Operation"
    log_info "========================================"
    log_info ""
    
    # Take snapshot of current UUIDs and block devices before attaching
    local old_uuids=($(wsl_get_disk_uuids))
    local old_devs=($(wsl_get_block_devices))
    
    # Try to attach the VHD (will succeed if not attached, fail silently if already attached)
    local mount_uuid=""
    local newly_attached=false
    
    if wsl_attach_vhd "$mount_path" "$mount_name" 2>/dev/null; then
        newly_attached=true
        # Register VHD for cleanup (will be unregistered on successful mount)
        register_vhd_cleanup "$mount_path" "" "$mount_name"
        log_success "VHD attached successfully"
        
        # Detect new UUID using snapshot-based detection
        mount_uuid=$(detect_new_uuid_after_attach "old_uuids")
        if [[ -n "$mount_uuid" ]]; then
            # Update cleanup registration with UUID
            unregister_vhd_cleanup "$mount_path" 2>/dev/null || true
            register_vhd_cleanup "$mount_path" "$mount_uuid" "$mount_name"
        fi
        
        # Find the new device (for unformatted VHD detection)
        local new_devs=($(wsl_get_block_devices))
        declare -A seen_dev
        local dev
        for dev in "${old_devs[@]}"; do
            seen_dev["$dev"]=1
        done
        local new_dev=""
        for dev in "${new_devs[@]}"; do
            if [[ -z "${seen_dev[$dev]:-}" ]]; then
                new_dev="$dev"
                break
            fi
        done
        
        # If no UUID found, the VHD is unformatted
        if [[ -z "$mount_uuid" ]]; then
            if [[ -z "$new_dev" ]]; then
                error_exit "Failed to detect device of attached VHD"
            fi
            
            local format_help="The VHD is attached but not formatted.
  Device: /dev/$new_dev

To format the VHD, run:
  $0 format --name $new_dev --type ext4

Or use a different filesystem type (ext3, xfs, etc.):
  $0 format --name $new_dev --type xfs"
            error_exit "VHD has no filesystem" 1 "$format_help"
        fi
        
        log_info "  Detected UUID: $mount_uuid"
        [[ -n "$new_dev" ]] && log_info "  Detected Device: /dev/$new_dev"
    else
        # VHD might already be attached, try to find it safely
        log_warn "VHD appears to be already attached, searching for UUID..."
        
        # Use safe UUID discovery with multi-VHD detection
        local discovery_result
        mount_uuid=$(wsl_find_uuid_by_path "$mount_path" 2>&1)
        discovery_result=$?
        
        # Handle discovery result with consistent error handling
        handle_uuid_discovery_result "$discovery_result" "$mount_uuid" "mount" "$mount_path"
    fi
    
    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$mount_uuid"
    log_info ""
    
    # Check if already mounted at the specific mount point
    local current_mount_point
    current_mount_point=$(wsl_get_vhd_mount_point "$mount_uuid")
    
    if [[ -n "$current_mount_point" ]] && [[ "$current_mount_point" == "$mount_point" ]]; then
        log_success "VHD is already mounted at $mount_point"
        log_info "Nothing to do."
        # Already mounted - unregister from cleanup tracking
        unregister_vhd_cleanup "$mount_path" 2>/dev/null || true
    else
        if [[ -n "$current_mount_point" ]]; then
            log_warn "VHD is mounted at a different location: $current_mount_point"
            log_info "Mounting to requested location: $mount_point"
        else
            log_warn "VHD is attached but not mounted"
        fi
        
        # Create mount point if it doesn't exist
        if [[ ! -d "$mount_point" ]]; then
            log_info "Creating mount point: $mount_point"
            if ! create_mount_point "$mount_point"; then
                error_exit "Failed to create mount point"
            fi
        fi
        
        log_info "Mounting VHD to $mount_point..."
        if wsl_mount_vhd "$mount_uuid" "$mount_point"; then
            log_success "VHD mounted successfully"
            
            # Update mount point in tracking file
            update_vhd_mount_points "$mount_path" "$mount_point"
            
            # Unregister from cleanup tracking - operation completed successfully
            unregister_vhd_cleanup "$mount_path" 2>/dev/null || true
        else
            error_exit "Failed to mount VHD"
        fi
    fi

    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$mount_uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Mount operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if wsl_is_vhd_mounted "$mount_uuid"; then
            echo "$mount_path ($mount_uuid): attached,mounted"
        else
            echo "$mount_path ($mount_uuid): mount failed"
        fi
    fi
}

# Function to unmount VHD
umount_vhd() {
    # Parse umount command arguments
    local umount_path=""
    local umount_uuid=""
    local umount_point=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                umount_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                umount_uuid="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--mount-point requires a value"
                fi
                if ! validate_mount_point "$2"; then
                    error_exit "Invalid mount point format: $2" 1 "Mount point must be an absolute path (e.g., /mnt/data)"
                fi
                umount_point="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown umount option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Try to discover UUID if not provided
    if [[ -z "$umount_uuid" ]]; then
        if [[ -n "$umount_path" ]]; then
            # Try to find UUID by path with multi-VHD safety
            local discovery_result
            umount_uuid=$(wsl_find_uuid_by_path "$umount_path" 2>&1)
            discovery_result=$?
            
            # Handle discovery result with consistent error handling
            handle_uuid_discovery_result "$discovery_result" "$umount_uuid" "umount" "$umount_path"
            log_info ""
        elif [[ -n "$umount_point" ]]; then
            # Try to find UUID by mount point
            umount_uuid=$(wsl_find_uuid_by_mountpoint "$umount_point")
            if [[ -n "$umount_uuid" ]]; then
                log_info "Discovered UUID from mount point: $umount_uuid"
                log_info ""
            fi
        fi
    fi
    
    # If UUID still not found, report error
    if [[ -z "$umount_uuid" ]]; then
        local uuid_help="Could not discover UUID. Please provide one of:
  --uuid UUID           Explicit UUID
  --path PATH           VHD file path (will attempt discovery)
  --mount-point PATH    Mount point (will attempt discovery)

To find UUID, run: $0 status --all"
        if [[ "$QUIET" == "true" ]]; then
            echo "uuid not found"
        fi
        error_exit "Unable to identify VHD" 1 "$uuid_help"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Unmount Operation"
    log_info "========================================"
    log_info ""
    
    if ! wsl_is_vhd_attached "$umount_uuid"; then
        log_warn "VHD is not attached to WSL"
        log_info "Nothing to do."
        log_info "========================================"
        exit 0
    fi
    
    log_info "VHD is attached to WSL"
    log_info ""
    
    # First, unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$umount_uuid"; then
        # Discover mount point if not provided
        if [[ -z "$umount_point" ]]; then
            umount_point=$(wsl_get_vhd_mount_point "$umount_uuid")
        fi
        
        log_info "Unmounting VHD from $umount_point..."
        if wsl_umount_vhd "$umount_point"; then
            log_success "VHD unmounted successfully"
            
            # Clear mount point in tracking file if we have the path
            if [[ -n "$umount_path" ]]; then
                update_vhd_mount_points "$umount_path" ""
            fi
        else
            error_exit "Failed to unmount VHD"
        fi
    else
        log_warn "VHD is not mounted to filesystem"
    fi
    
    # Then, detach from WSL (only if path was provided)
    if [[ -n "$umount_path" ]]; then
        log_info "Detaching VHD from WSL..."
        # Get VHD name from tracking file for history
        local umount_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$umount_path")
            umount_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        if wsl_detach_vhd "$umount_path" "$umount_uuid" "$umount_name"; then
            log_success "VHD detached successfully"
        else
            error_exit "Failed to detach VHD from WSL"
        fi
    else
        log_warn "VHD was not detached from WSL"
        log_info "The VHD path is required to detach from WSL."
        log_info ""
        log_info "To fully detach the VHD, run:"
        log_info "  $0 detach --path <VHD_PATH>"
    fi

    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$umount_uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Unmount operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if ! wsl_is_vhd_attached "$umount_uuid"; then
            echo "$umount_path ($umount_uuid): detached"
        elif [[ -z "$umount_path" ]]; then
            echo "($umount_uuid): unmounted,attached"
        else
            echo "$umount_path ($umount_uuid): umount failed"
        fi
    fi
}

# Function to detach VHD by UUID
detach_vhd() {
    # Parse detach command arguments
    local detach_uuid=""
    local detach_path=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                detach_uuid="$2"
                shift 2
                ;;
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                detach_path="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown detach option '$1'" 1 "$(show_usage)"
                ;;
        esac
    done
    
    # Validate that UUID is provided
    if [[ -z "$detach_uuid" ]]; then
        error_exit "--uuid is required" 1 "Use --uuid to specify the VHD UUID to detach. To find UUIDs, run: $0 status --all"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Detach Operation"
    log_info "========================================"
    log_info ""
    
    # Check if VHD is attached
    if ! wsl_is_vhd_attached "$detach_uuid"; then
        log_warn "VHD is not attached to WSL"
        log_info "Nothing to do."
        [[ "$QUIET" == "true" ]] && echo "$detach_uuid: not attached"
        log_info "========================================"
        exit 0
    fi
    
    log_info "VHD is attached to WSL"
    log_info "  UUID: $detach_uuid"
    log_info ""
    
    # Path is optional for detach - WSL can detach by UUID alone
    # If path is provided, it will be used; otherwise detach will work without it
    
    # Show current VHD info
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$detach_uuid"
    log_info ""
    
    # Check if mounted and unmount first
    if wsl_is_vhd_mounted "$detach_uuid"; then
        local mount_point=$(wsl_get_vhd_mount_point "$detach_uuid")
        log_info "VHD is mounted at: $mount_point"
        log_info "Unmounting VHD first..."
        
        if wsl_umount_vhd "$mount_point"; then
            log_success "VHD unmounted successfully"
            
            # Clear mount point in tracking file if we have the path
            if [[ -n "$detach_path" ]]; then
                update_vhd_mount_points "$detach_path" ""
            fi
        else
            error_exit "Failed to unmount VHD"
        fi
        log_info ""
    else
        log_info "VHD is not mounted to filesystem"
        log_info ""
    fi
    
    # Detach from WSL
    log_info "Detaching VHD from WSL..."
    
    if [[ -n "$detach_path" ]]; then
        # Get VHD name from tracking file for history
        local detach_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$detach_path")
            detach_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        
        # Use path if we have it, pass UUID and name for history tracking
        if wsl_detach_vhd "$detach_path" "$detach_uuid" "$detach_name"; then
            log_success "VHD detached successfully"
        else
            error_exit "Failed to detach VHD from WSL"
        fi
    else
        # If we couldn't find the path, report error with helpful message
        local path_help="The VHD path could not be found automatically.
Please provide the path explicitly:
  $0 detach --uuid $detach_uuid --path <vhd_path>

Or use the umount command if you know the path or mount point:
  $0 umount --path <vhd_path>
  $0 umount --mount-point <mount_point>"
        error_exit "Could not determine VHD path" 1 "$path_help"
    fi
    
    log_info ""
    log_info "========================================"
    log_info "  Detach operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if ! wsl_is_vhd_attached "$detach_uuid"; then
            echo "$detach_uuid: detached"
        else
            echo "$detach_uuid: detach failed"
        fi
    fi
}

# Function to delete VHD
delete_vhd() {
    # Parse delete command arguments
    local delete_path=""
    local delete_uuid=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                delete_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                delete_uuid="$2"
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
    
    # Validate that at least path is provided
    if [[ -z "$delete_path" ]]; then
        error_exit "VHD path is required" 1 "Use --path to specify the VHD file path"
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$delete_path")
    if [[ ! -e "$vhd_path_wsl" ]]; then
        error_exit "VHD file does not exist at $delete_path (WSL path: $vhd_path_wsl)"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Deletion"
    log_info "========================================"
    log_info ""
    
    # Try to discover UUID if not provided
    if [[ -z "$delete_uuid" ]]; then
        local discovery_result
        delete_uuid=$(wsl_find_uuid_by_path "$delete_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 2 ]]; then
            # Multiple VHDs detected - not a blocker for delete, just can't verify attachment
            log_warn "Multiple VHDs attached - cannot verify if this VHD is attached"
            log_info "Proceeding with caution..."
            log_info ""
            delete_uuid=""  # Clear to skip attachment check
        elif [[ -n "$delete_uuid" ]]; then
            log_info "Discovered UUID from path: $delete_uuid"
            log_info ""
        fi
    fi
    
    # Check if VHD is currently attached
    if [[ -n "$delete_uuid" ]] && wsl_is_vhd_attached "$delete_uuid"; then
        # Try to automatically detach before failing
        log_warn "VHD is currently attached to WSL"
        log_info "Attempting to detach automatically..."
        
        # Try umount first (handles both unmount and detach)
        if [[ -n "$delete_path" ]]; then
            if bash "$0" -q umount --path "$delete_path" >/dev/null 2>&1; then
                log_success "VHD detached successfully"
                # Wait a moment for detachment to complete
                sleep 1
            else
                # Umount failed, try direct wsl.exe --unmount as fallback
                if wsl.exe --unmount "$delete_path" >/dev/null 2>&1; then
                    log_success "VHD detached successfully"
                    sleep 1
                else
                    local detach_help="The VHD must be unmounted and detached before deletion.
To unmount and detach, run:
  $0 umount --path $delete_path

Then try the delete command again."
                    error_exit "VHD is currently attached to WSL and could not be detached" 1 "$detach_help"
                fi
            fi
        else
            local detach_help="The VHD must be unmounted and detached before deletion.
To unmount and detach, run:
  $0 umount --uuid $delete_uuid

Then try the delete command again."
            error_exit "VHD is currently attached to WSL" 1 "$detach_help"
        fi
    fi
    
    log_info "VHD file: $delete_path"
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
    if wsl_delete_vhd "$delete_path"; then
        log_success "VHD deleted successfully"
        [[ "$QUIET" == "true" ]] && echo "$delete_path: deleted"
        
        # Remove mapping from tracking file
        remove_vhd_mapping "$delete_path"
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
create_vhd() {
    # Parse create command arguments
    local create_path=""
    local default_size="${DEFAULT_VHD_SIZE:-1G}"
    local create_size="$default_size"
    local force="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                create_path="$2"
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
    if [[ -z "$create_path" ]]; then
        error_exit "VHD path is required" 1 "Use --path to specify the VHD file path"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Creation"
    log_info "========================================"
    log_info ""
    
    # Check if VHD already exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$create_path")
    if [[ -e "$vhd_path_wsl" ]]; then
        if [[ "$force" == "false" ]]; then
            local exists_help="Use 'mount' command to attach the existing VHD, or use --force to overwrite"
            error_exit "VHD file already exists at $create_path" 1 "$exists_help"
        else
            # Force mode: prompt for confirmation before deleting
            log_warn "VHD file already exists at $create_path"
            log_info ""
            
            # Check if VHD is currently attached (with multi-VHD safety)
            local existing_uuid
            local discovery_result
            existing_uuid=$(wsl_find_uuid_by_path "$create_path" 2>&1)
            discovery_result=$?
            
            # If UUID discovery failed due to multiple VHDs, try tracking file directly
            if [[ $discovery_result -eq 2 ]]; then
                # Multiple VHDs attached - try tracking file lookup
                local tracked_uuid=$(lookup_vhd_uuid "$create_path")
                if [[ -n "$tracked_uuid" ]] && wsl_is_vhd_attached "$tracked_uuid"; then
                    existing_uuid="$tracked_uuid"
                    discovery_result=0
                fi
            fi
            
            # Check if VHD needs to be unmounted/detached
            local needs_unmount=false
            if [[ $discovery_result -eq 0 && -n "$existing_uuid" ]] && wsl_is_vhd_attached "$existing_uuid"; then
                needs_unmount=true
            elif [[ $discovery_result -eq 2 ]]; then
                # Multiple VHDs - try to unmount by path directly using wsl.exe
                # This works even when UUID discovery fails
                needs_unmount=true
            fi
            
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
                        log_info "  $0 umount --path $create_path"
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
                    # Get VHD name from tracking file for history
                    local existing_name=""
                    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                        local normalized_path=$(normalize_vhd_path "$create_path")
                        existing_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
                    fi
                    if wsl_detach_vhd "$create_path" "$existing_uuid" "$existing_name"; then
                        log_success "VHD detached from WSL"
                        log_info ""
                    else
                        error_exit "Failed to detach VHD from WSL"
                    fi
                else
                    # Multiple VHDs or UUID not found - try direct unmount by path
                    log_info "Attempting to unmount by path (UUID discovery ambiguous)..."
                    if wsl.exe --unmount "$create_path" 2>/dev/null; then
                        log_success "VHD detached from WSL (via direct unmount)"
                        log_info ""
                    else
                        log_warn "Direct unmount failed - file may still be locked"
                        log_info "Attempting to continue with file deletion..."
                    fi
                fi
                
                # Small delay to ensure detachment is complete
                sleep 2
            fi
            
            # Confirmation prompt in non-quiet mode (unless YES flag is set)
            if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
                log_warn "WARNING: This will permanently delete the existing VHD file!"
                echo -n "Are you sure you want to overwrite $create_path? (yes/no): "
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
    log_info "  Path: $create_path"
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
    log_info "========================================"
    log_info "  Creation completed"
    log_info "========================================"
    log_info ""
    log_info "The VHD file has been created but is not attached or formatted."
    log_info "To use it, you need to:"
    log_info "  1. Attach the VHD:"
    log_info "     $0 attach --path $create_path --name <name>"
    log_info "  2. Format the VHD:"
    log_info "     $0 format --name <device_name> --type ext4"
    log_info "  3. Mount the formatted VHD:"
    log_info "     $0 mount --path $create_path --mount-point <mount_point>"
    log_info ""
    
    if [[ "$QUIET" == "true" ]]; then
        echo "$create_path: created"
    fi
}

# Function to resize VHD
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
    local target_vhd_name=""
    
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
            # Extract name from tracking file if available
            target_vhd_name=$(jq -r --arg uuid "$target_uuid" "$JQ_GET_NAME_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        fi
    fi
    
    # If path lookup failed, try to infer from mount point name as fallback
    if [[ -z "$target_vhd_path" ]]; then
        target_vhd_name=$(basename "$target_mount_point")
        local path_help="The VHD path is required for resize operation.
Please ensure the VHD was attached/mounted using disk_management.sh so it's tracked.
Alternatively, you can manually specify the path by modifying the resize command."
        error_exit "Cannot determine VHD path from tracking file" 1 "$path_help"
    fi
    
    log_info "Target VHD path: $target_vhd_path"
    if [[ -n "$target_vhd_name" ]]; then
        log_info "Target VHD name: $target_vhd_name"
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
    if new_uuid=$(wsl_create_vhd "$new_vhd_path" "$actual_size_str" "ext4" "${target_vhd_basename}_temp" 2>&1); then
        log_success "New VHD created"
        log_info "  New UUID: $new_uuid"
        # Register new VHD for cleanup (will be unregistered on successful completion)
        register_vhd_cleanup "$new_vhd_path" "$new_uuid" "${target_vhd_basename}_temp"
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
    
    # Get VHD names from tracking file for history
    local target_name=""
    local new_name=""
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        local normalized_target=$(normalize_vhd_path "$target_vhd_path")
        local normalized_new=$(normalize_vhd_path "$new_vhd_path")
        target_name=$(jq -r --arg path "$normalized_target" "$JQ_GET_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
        new_name=$(jq -r --arg path "$normalized_new" "$JQ_GET_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
    fi
    
    if ! wsl_detach_vhd "$target_vhd_path" "$target_uuid" "$target_name"; then
        error_exit "Failed to detach target disk"
    fi
    log_success "Target disk detached"
    log_info ""
    
    # Rename target VHD to backup
    local target_vhd_path_wsl
    target_vhd_path_wsl=$(wsl_convert_path "$target_vhd_path")
    local backup_vhd_path_wsl="${target_vhd_path_wsl%.vhdx}_bkp.vhdx"
    local backup_vhd_path_wsl="${backup_vhd_path_wsl%.vhd}_bkp.vhd"
    
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
    
    if ! wsl_detach_vhd "$new_vhd_path" "$new_uuid" "$new_name"; then
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
    local old_uuids=($(wsl_get_disk_uuids))
    
    if ! wsl_attach_vhd "$target_vhd_path" "$target_vhd_name"; then
        error_exit "Failed to attach resized VHD"
    fi
    
    # Detect new UUID using snapshot-based detection
    local final_uuid
    final_uuid=$(detect_new_uuid_after_attach "old_uuids")
    
    if [[ -z "$final_uuid" ]]; then
        error_exit "Failed to detect UUID of resized VHD"
    fi
    
    # Mount the resized VHD
    if wsl_mount_vhd "$final_uuid" "$target_mount_point"; then
        log_success "Resized VHD mounted"
        
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
format_vhd_command() {
    # Parse format command arguments
    local format_name=""
    local format_uuid=""
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    local format_type="$default_fs"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--name requires a value"
                fi
                if ! validate_device_name "$2"; then
                    error_exit "Invalid device name format: $2" 1 "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde)"
                fi
                format_name="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--uuid requires a value"
                fi
                if ! validate_uuid "$2"; then
                    error_exit "Invalid UUID format: $2" 1 "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                fi
                format_uuid="$2"
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
    if [[ -z "$format_name" && -z "$format_uuid" ]]; then
        local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
        local format_help="Usage: $0 format [OPTIONS]

Options:
  --name NAME   - VHD device block name (e.g., sdd, sde)
  --uuid UUID   - VHD UUID
  --type TYPE   - Filesystem type [default: $default_fs]

Examples:
  $0 format --name sdd --type ext4
  $0 format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4

To find attached VHDs, run: $0 status --all"
        error_exit "Either --name or --uuid is required" 1 "$format_help"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Format Operation"
    log_info "========================================"
    log_info ""
    
    local device_name=""
    local target_identifier=""
    
    # Determine device name based on provided arguments
    if [[ -n "$format_uuid" ]]; then
        # Check if UUID exists and if it's already formatted
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$format_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
        fi
        device_name=$(lsblk -f -J | jq -r --arg UUID "$format_uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        
        if [[ -z "$device_name" ]]; then
            local uuid_help="The UUID might be incorrect or the VHD is not attached.
To find attached VHDs, run: $0 status --all"
            error_exit "No device found with UUID: $format_uuid" 1 "$uuid_help"
        fi
        
        # Validate device name format for security before use in mkfs
        if ! validate_device_name "$device_name"; then
            local device_help="Device name must match pattern: sd[a-z]+ (e.g., sdd, sde, sdaa)
This is a security check to prevent command injection."
            error_exit "Invalid device name format: $device_name" 1 "$device_help"
        fi
        
        # Warn user that disk is already formatted
        log_warn "WARNING: Device /dev/$device_name is already formatted"
        log_info "  Current UUID: $format_uuid"
        log_info ""
        log_info "Formatting will destroy all existing data and generate a new UUID."
        
        if [[ "$QUIET" == "false" ]] && [[ "$YES" == "false" ]]; then
            echo -n "Are you sure you want to format /dev/$device_name? (yes/no): "
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
        
        target_identifier="UUID $format_uuid"
    else
        # Using device name directly
        device_name="$format_name"
        target_identifier="device name $format_name"
        
        # Validate device exists
        if [[ ! -b "/dev/$device_name" ]]; then
            local device_help="Please check the device name is correct.
To find attached VHDs, run: $0 status --all"
            error_exit "Block device /dev/$device_name does not exist" 1 "$device_help"
        fi
        
        # Check if device has existing UUID (already formatted)
        # Use safe_sudo_capture for blkid command
        local existing_uuid
        existing_uuid=$(safe_sudo_capture blkid -s UUID -o value "/dev/$device_name" 2>/dev/null)
        if [[ -n "$existing_uuid" ]]; then
            log_warn "WARNING: Device /dev/$device_name is already formatted"
            log_info "  Current UUID: $existing_uuid"
            log_info ""
            log_info "Formatting will destroy all existing data and generate a new UUID."
            
            if [[ "$QUIET" == "false" ]]; then
                echo -n "Are you sure you want to format /dev/$device_name? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    log_info "Format operation cancelled."
                    exit 0
                fi
                log_info ""
            fi
        else
            log_success "Device /dev/$device_name is not formatted"
            log_info ""
        fi
    fi
    
    log_info "Formatting device /dev/$device_name with $format_type..."
    log_info "  Target: $target_identifier"
    log_info ""
    
    # Format using helper function
    local new_uuid=$(format_vhd "$device_name" "$format_type")
    if [[ $? -ne 0 || -z "$new_uuid" ]]; then
        error_exit "Failed to format device /dev/$device_name"
    fi
    
    log_success "VHD formatted successfully"
    log_info "  Device: /dev/$device_name"
    log_info "  New UUID: $new_uuid"
    log_info "  Filesystem: $format_type"
    
    # Note: We cannot automatically update path→UUID mapping here because format
    # command doesn't require path parameter. The mapping will be updated when
    # attach/mount operations are performed with the new UUID.
    
    log_info ""
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$new_uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Format operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        echo "/dev/$device_name: formatted with UUID=$new_uuid"
    fi
}

# Function to attach VHD
attach_vhd() {
    # Parse attach command arguments
    local attach_path=""
    local attach_name="$VHD_NAME"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
                fi
                if ! validate_windows_path "$2"; then
                    error_exit "Invalid path format: $2" 1 "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                fi
                attach_path="$2"
                shift 2
                ;;
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--name requires a value"
                fi
                if ! validate_vhd_name "$2"; then
                    error_exit "Invalid VHD name format: $2" 1 "VHD name must contain only alphanumeric characters, hyphens, and underscores"
                fi
                attach_name="$2"
                shift 2
                ;;
            *)
                error_exit "Unknown option: $1" 1 "Use --help to see available options"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$attach_path" ]]; then
        error_exit "VHD path is required. Use --path option."
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$attach_path")
    if [[ ! -e "$vhd_path_wsl" ]]; then
        error_exit "VHD file does not exist: $attach_path (WSL path: $vhd_path_wsl)"
    fi
    
    log_info "========================================"
    log_info "  VHD Disk Attach Operation"
    log_info "========================================"
    log_info ""
    
    # Take snapshot of current UUIDs and block devices before attaching
    local old_uuids=($(wsl_get_disk_uuids))
    local old_devs=($(wsl_get_block_devices))
    
    # Try to attach the VHD (will succeed if not attached, fail silently if already attached)
    local attach_uuid=""
    local newly_attached=false
    
    if wsl_attach_vhd "$attach_path" "$attach_name" 2>/dev/null; then
        newly_attached=true
        # Register VHD for cleanup (will be unregistered on successful completion)
        register_vhd_cleanup "$attach_path" "" "$attach_name"
        log_success "VHD attached to WSL"
        log_info "  Path: $attach_path"
        log_info "  Name: $attach_name"
        log_info ""
        
        # Detect new UUID using snapshot-based detection
        attach_uuid=$(detect_new_uuid_after_attach "old_uuids")
        if [[ -n "$attach_uuid" ]]; then
            # Update cleanup registration with UUID
            unregister_vhd_cleanup "$attach_path" 2>/dev/null || true
            register_vhd_cleanup "$attach_path" "$attach_uuid" "$attach_name"
        fi
        
        if [[ -z "$attach_uuid" ]]; then
            log_warn "Warning: Could not automatically detect UUID"
            log_info "  The VHD was attached successfully but UUID detection failed."
            log_info "  You can find the UUID using: ./disk_management.sh status --all"
        else
            # Find the device name
            if [[ "$DEBUG" == "true" ]]; then
                log_debug "lsblk -f -J | jq -r --arg UUID '$attach_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
            fi
            local new_dev=$(lsblk -f -J | jq -r --arg UUID "$attach_uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            
            log_success "Device detected"
            log_info "  UUID: $attach_uuid"
            [[ -n "$new_dev" ]] && log_info "  Device: /dev/$new_dev"
            
            # Save mapping to tracking file with VHD name
            save_vhd_mapping "$attach_path" "$attach_uuid" "" "$attach_name"
            
            # Unregister from cleanup tracking - operation completed successfully
            unregister_vhd_cleanup "$attach_path" 2>/dev/null || true
        fi
    else
        # Attachment failed - VHD might already be attached
        log_warn "VHD attachment failed - checking if already attached..."
        log_info ""
        
        # Try to find the UUID with multi-VHD safety
        local discovery_result
        attach_uuid=$(wsl_find_uuid_by_path "$attach_path" 2>&1)
        discovery_result=$?
        
        # Handle discovery result with consistent error handling
        handle_uuid_discovery_result "$discovery_result" "$attach_uuid" "attach" "$attach_path"
        
        if wsl_is_vhd_attached "$attach_uuid"; then
            log_success "VHD is already attached to WSL"
            log_info "  UUID: $attach_uuid"
            
            # Get device name
            if [[ "$DEBUG" == "true" ]]; then
                log_debug "lsblk -f -J | jq -r --arg UUID '$attach_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
            fi
            local dev_name=$(lsblk -f -J | jq -r --arg UUID "$attach_uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
            [[ -n "$dev_name" ]] && log_info "  Device: /dev/$dev_name"
            
            # Save mapping to tracking file (idempotent - updates if exists) with VHD name
            save_vhd_mapping "$attach_path" "$attach_uuid" "" "$attach_name"
            
            # Unregister from cleanup tracking - operation completed successfully
            unregister_vhd_cleanup "$attach_path" 2>/dev/null || true
        else
            local attach_help="The VHD might already be attached with a different name or path.
Try running: ./disk_management.sh status --all"
            error_exit "Failed to attach VHD" 1 "$attach_help"
        fi
    fi
    
    log_info ""
    [[ -n "$attach_uuid" ]] && [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$attach_uuid"
    
    log_info ""
    log_info "========================================"
    log_info "  Attach operation completed"
    log_info "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if [[ -n "$attach_uuid" ]]; then
            echo "$attach_path ($attach_uuid): attached"
        else
            echo "$attach_path: attached (UUID unknown)"
        fi
    fi
}

# Function to show detach history
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
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error_exit "--path requires a value"
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
        local history_json=$(get_last_detach_for_path "$show_path")
        
        if [[ -n "$history_json" ]]; then
            if [[ "$QUIET" == "true" ]]; then
                echo "$history_json"
            else
                local path=$(echo "$history_json" | jq -r '.path')
                local uuid=$(echo "$history_json" | jq -r '.uuid')
                local name=$(echo "$history_json" | jq -r '.name // empty')
                local timestamp=$(echo "$history_json" | jq -r '.timestamp')
                
                echo "Path: $path"
                echo "UUID: $uuid"
                [[ -n "$name" ]] && echo "Name: $name"
                echo "Last detached: $timestamp"
            fi
        else
            log_info "No detach history found for path: $show_path"
            [[ "$QUIET" == "true" ]] && echo "{}"
        fi
    else
        # Show recent history
        local history_json=$(get_detach_history "$limit")
        
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

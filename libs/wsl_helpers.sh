#!/bin/bash

# WSL Helper Functions Library
# This file contains reusable functions for managing VHD disks in WSL

# Source configuration file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
if [[ -f "$PARENT_DIR/config.sh" ]]; then
    source "$PARENT_DIR/config.sh"
fi

# Source utility functions for validation (if not already sourced)
# Note: utils.sh should be sourced before this file, but we try here as fallback
if ! command -v validate_windows_path &>/dev/null; then
    source "$SCRIPT_DIR/utils.sh" 2>/dev/null || true
fi

# Colors for output (fallback if config.sh not found)
if [[ -z "${GREEN:-}" ]]; then
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export RED='\033[0;31m'
    export BLUE='\033[0;34m'
    export NC='\033[0m' # No Color
fi

# Persistent disk tracking file location (use config value or default)
DISK_TRACKING_FILE="${DISK_TRACKING_FILE:-$HOME/.config/wsl-disk-management/vhd_mapping.json}"

# Initialize the disk tracking file if it doesn't exist
# Creates directory and empty JSON structure
init_disk_tracking_file() {
    local dir=$(dirname "$DISK_TRACKING_FILE")
    
    if [[ ! -d "$dir" ]]; then
        if debug_cmd mkdir -p "$dir" 2>/dev/null; then
            log_debug "Created tracking directory: $dir"
        else
            log_warn "Failed to create tracking directory: $dir"
            return 1
        fi
    fi
    
    if [[ ! -f "$DISK_TRACKING_FILE" ]]; then
        echo '{"version":"1.0","mappings":{},"detach_history":[]}' > "$DISK_TRACKING_FILE"
        log_debug "Initialized tracking file: $DISK_TRACKING_FILE"
    fi
    
    return 0
}

# Normalize Windows path for consistent tracking
# Converts to forward slashes and lowercase for case-insensitive matching
# Args: $1 - Windows path (e.g., C:\VMs\disk.vhdx or C:/VMs/disk.vhdx)
# Returns: Normalized path (e.g., c:/vms/disk.vhdx)
normalize_vhd_path() {
    local path="$1"
    # Convert backslashes to forward slashes, then lowercase
    echo "$path" | tr '\\' '/' | tr '[:upper:]' '[:lower:]'
}

# Check if a VHD path is test-related
# Args: $1 - VHD path (Windows format)
# Returns: 0 if test VHD, 1 if not
# Test VHDs are identified by:
#   - Path is within WSL_DISKS_DIR from .env.test (if set)
#   - Path contains "test" (case-insensitive) in filename or directory (fallback)
#   - Path contains "wsl_tests" directory (fallback)
is_test_vhd() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    local normalized=$(normalize_vhd_path "$path")
    
    # Check if WSL_DISKS_DIR is set (from .env.test) and path is within it
    # This is the primary method when running tests
    if [[ -n "${WSL_DISKS_DIR:-}" ]]; then
        local test_dir_normalized=$(normalize_vhd_path "$WSL_DISKS_DIR")
        if [[ "$normalized" == "$test_dir_normalized"* ]]; then
            return 0
        fi
    fi
    
    # Fallback: Check if path contains "test" or "wsl_tests" (case-insensitive)
    # This catches test VHDs even if WSL_DISKS_DIR is not set
    if [[ "$normalized" == *"test"* ]] || [[ "$normalized" == *"wsl_tests"* ]]; then
        return 0
    fi
    
    return 1
}

# Save path→UUID mapping to tracking file
# Args: $1 - VHD path (Windows format)
#       $2 - UUID
#       $3 - Mount point (optional, can be empty or comma-separated list)
#       $4 - Device name (optional, e.g., sde, sdd)
# Returns: 0 on success, 1 on failure
save_vhd_mapping() {
    local path="$1"
    local uuid="$2"
    local mount_points="$3"
    local dev_name="${4:-}"
    
    if [[ -z "$path" || -z "$uuid" ]]; then
        log_debug "save_vhd_mapping: path or uuid is empty"
        return 1
    fi
    
    # Validate inputs for security
    if ! validate_windows_path "$path"; then
        log_debug "save_vhd_mapping: invalid path format"
        return 1
    fi
    
    if ! validate_uuid "$uuid"; then
        log_debug "save_vhd_mapping: invalid UUID format"
        return 1
    fi
    
    if [[ -n "$dev_name" ]] && ! validate_device_name "$dev_name"; then
        log_debug "save_vhd_mapping: invalid device name format"
        return 1
    fi
    
    init_disk_tracking_file || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create secure temporary file using mktemp
    local temp_file
    temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
    if [[ $? -ne 0 || -z "$temp_file" ]]; then
        log_debug "Failed to create temporary file"
        return 1
    fi
    
    # Set up trap handler to clean up temp file on exit/interrupt
    # Use inline trap command to avoid function definition issues
    trap "rm -f '$temp_file'" EXIT INT TERM
    
    # Ensure jq is available
    if ! command -v jq &> /dev/null; then
        log_debug "jq not available, skipping mapping save"
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
    
    # Update JSON with new mapping
    log_debug "jq --arg path '$normalized' --arg uuid '$uuid' --arg mp '$mount_points' --arg dev_name '$dev_name' --arg ts '$timestamp' ..."
    
    if jq --arg path "$normalized" \
          --arg uuid "$uuid" \
          --arg mp "$mount_points" \
          --arg dev_name "$dev_name" \
          --arg ts "$timestamp" \
          "$JQ_SAVE_MAPPING" \
          "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$DISK_TRACKING_FILE"
        trap - EXIT INT TERM
        log_debug "Saved mapping: $normalized → $uuid (dev_name: $dev_name)"
        return 0
    else
        rm -f "$temp_file"
        trap - EXIT INT TERM
        log_debug "Failed to save mapping"
        return 1
    fi
}

# Lookup UUID by VHD path from tracking file
# Args: $1 - VHD path (Windows format)
# Returns: UUID if found, empty string if not found
# Exit code: 0 if found, 1 if not found
lookup_vhd_uuid() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    # Validate path format for security
    if ! validate_windows_path "$path"; then
        return 1
    fi
    
    init_disk_tracking_file || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    log_debug "jq -r --arg path '$normalized' '.mappings[\$path].uuid // empty' $DISK_TRACKING_FILE"
    
    local uuid=$(jq -r --arg path "$normalized" "$JQ_GET_UUID_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
    
    if [[ -n "$uuid" && "$uuid" != "null" ]]; then
        echo "$uuid"
        return 0
    fi
    
    return 1
}

# Lookup UUID by device name from tracking file
# Args: $1 - Device name (e.g., sde, sdd)
# Returns: UUID if found, empty string if not found
# Exit code: 0 if found, 1 if not found
lookup_vhd_uuid_by_dev_name() {
    local dev_name="$1"
    
    if [[ -z "$dev_name" ]]; then
        return 1
    fi
    
    # Validate device name format for security
    if ! validate_device_name "$dev_name"; then
        return 1
    fi
    
    init_disk_tracking_file || return 1
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    log_debug "jq -r --arg dev_name '$dev_name' '.mappings[] | select(.dev_name == \$dev_name) | .uuid' $DISK_TRACKING_FILE"
    
    local uuid=$(jq -r --arg dev_name "$dev_name" '.mappings[] | select(.dev_name == $dev_name) | .uuid' "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
    
    if [[ -n "$uuid" && "$uuid" != "null" && "$uuid" != "" ]]; then
        echo "$uuid"
        return 0
    fi
    
    return 1
}

# Update mount points for a VHD in tracking file
# Args: $1 - VHD path (Windows format)
#       $2 - Mount points (comma-separated list, empty to clear)
# Returns: 0 on success, 1 on failure
update_vhd_mount_points() {
    local path="$1"
    local mount_points="$2"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    # Skip tracking for test-related VHDs
    if is_test_vhd "$path"; then
        log_debug "Skipping mount points update for test VHD: $path"
        return 0
    fi
    
    init_disk_tracking_file || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    
    # Create secure temporary file using mktemp
    local temp_file
    temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
    if [[ $? -ne 0 || -z "$temp_file" ]]; then
        log_debug "Failed to create temporary file"
        return 1
    fi
    
    # Set up trap handler to clean up temp file on exit/interrupt
    # Use inline trap command to avoid function definition issues
    trap "rm -f '$temp_file'" EXIT INT TERM
    
    if ! command -v jq &> /dev/null; then
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
    
    # Check if mapping exists
    local exists=$(jq -r --arg path "$normalized" "$JQ_CHECK_MAPPING_EXISTS" "$DISK_TRACKING_FILE" 2>/dev/null)
    if [[ -z "$exists" || "$exists" == "null" ]]; then
        log_debug "No mapping found for $normalized to update"
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
    
    log_debug "Updating mount_points for $normalized to: $mount_points"
    
    if jq --arg path "$normalized" \
          --arg mp "$mount_points" \
          "$JQ_UPDATE_MOUNT_POINTS" \
          "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$DISK_TRACKING_FILE"
        trap - EXIT INT TERM
        return 0
    else
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
}

# Remove VHD mapping from tracking file
# Args: $1 - VHD path (Windows format)
# Returns: 0 on success, 1 on failure
remove_vhd_mapping() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    init_disk_tracking_file || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    
    # Create secure temporary file using mktemp
    local temp_file
    temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
    if [[ $? -ne 0 || -z "$temp_file" ]]; then
        log_debug "Failed to create temporary file"
        return 1
    fi
    
    # Set up trap handler to clean up temp file on exit/interrupt
    # Use inline trap command to avoid function definition issues
    trap "rm -f '$temp_file'" EXIT INT TERM
    
    if ! command -v jq &> /dev/null; then
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
    
    log_debug "Removing mapping for $normalized"
    
    if jq --arg path "$normalized" "$JQ_DELETE_MAPPING" \
          "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$DISK_TRACKING_FILE"
        trap - EXIT INT TERM
        return 0
    else
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
}

# Save detach event to detach history
# Args: $1 - VHD path (Windows format)
#       $2 - UUID
#       $3 - VHD name (optional, WSL mount name)
# Returns: 0 on success, 1 on failure
save_detach_history() {
    local path="$1"
    local uuid="$2"
    local dev_name="${3:-}"
    
    if [[ -z "$path" || -z "$uuid" ]]; then
        log_debug "save_detach_history: path or uuid is empty"
        return 1
    fi
    
    # Skip tracking for test-related VHDs
    if is_test_vhd "$path"; then
        log_debug "Skipping detach history save for test VHD: $path"
        return 0
    fi
    
    init_disk_tracking_file || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create secure temporary file using mktemp
    local temp_file
    temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
    if [[ $? -ne 0 || -z "$temp_file" ]]; then
        log_debug "Failed to create temporary file"
        return 1
    fi
    
    # Set up trap handler to clean up temp file on exit/interrupt
    # Use inline trap command to avoid function definition issues
    trap "rm -f '$temp_file'" EXIT INT TERM
    
    # Ensure jq is available
    if ! command -v jq &> /dev/null; then
        log_debug "jq not available, skipping detach history save"
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
    
    # Add detach event to history (keep last 50 entries)
    log_debug "Adding detach event to history: $normalized (uuid: $uuid, dev_name: $dev_name)"
    
    if jq --arg path "$normalized" \
          --arg uuid "$uuid" \
          --arg dev_name "$dev_name" \
          --arg ts "$timestamp" \
          "$JQ_SAVE_DETACH_HISTORY" \
          "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$DISK_TRACKING_FILE"
        trap - EXIT INT TERM
        log_debug "Saved detach event: $normalized → $uuid at $timestamp"
        return 0
    else
        rm -f "$temp_file"
        trap - EXIT INT TERM
        log_debug "Failed to save detach event"
        return 1
    fi
}

# Get detach history from tracking file
# Args: $1 - Number of entries to retrieve (optional, default: 10, max: 50)
# Returns: JSON array of detach events, most recent first
get_detach_history() {
    local default_limit="${DEFAULT_HISTORY_LIMIT:-10}"
    local max_limit="${MAX_HISTORY_LIMIT:-50}"
    local limit="${1:-$default_limit}"
    
    # Limit to max entries
    if [[ $limit -gt $max_limit ]]; then
        limit=$max_limit
    fi
    
    init_disk_tracking_file || return 1
    
    if ! command -v jq &> /dev/null; then
        echo "[]"  # Return empty array if jq not available
        return 1
    fi
    
    log_debug "jq -r '.detach_history // [] | .[0:$limit]' $DISK_TRACKING_FILE"
    
    jq -r --argjson limit "$limit" "$JQ_GET_DETACH_HISTORY" "$DISK_TRACKING_FILE" 2>/dev/null || echo "[]"
}

# Find most recent detach event for a VHD path
# Args: $1 - VHD path (Windows format)
# Returns: JSON object with detach event details if found, empty string otherwise
get_last_detach_for_path() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    init_disk_tracking_file || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    log_debug "Looking for last detach event for: $normalized"
    
    local result=$(jq -r --arg path "$normalized" \
        "$JQ_GET_LAST_DETACH_BY_PATH" \
        "$DISK_TRACKING_FILE" 2>/dev/null)
    
    if [[ -n "$result" && "$result" != "null" ]]; then
        echo "$result"
        return 0
    fi
    
    return 1
}

# Debug command wrapper - prints command before execution if DEBUG=true
# Usage: debug_cmd command [args...]
# Returns: exit code of the command
debug_cmd() {
    log_debug "Executing: $*"
    "$@"
    return $?
}

# Check if a VHD is attached to WSL by UUID
# Args: $1 - UUID of the VHD
# Returns: 0 if attached, 1 if not attached
wsl_is_vhd_attached() {
    local uuid="$1"
    local uuid_check
    
    if [[ -z "$uuid" ]]; then
        log_error "UUID is required"
        return 2
    fi
    
    # Validate UUID format for security
    if ! validate_uuid "$uuid"; then
        log_error "Invalid UUID format"
        return 2
    fi
    
    # Note: For pipelines, we show the first command for debug visibility
    log_debug "lsblk -f -J | jq --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .uuid'"
    uuid_check=$(lsblk -f -J | jq --arg UUID "$uuid" "$JQ_CHECK_UUID_EXISTS" 2>/dev/null)
    
    if [[ -n "$uuid_check" ]]; then
        return 0  # VHD is attached
    else
        return 1  # VHD is not attached
    fi
}

# Check if a VHD is mounted to the filesystem
# Args: $1 - UUID of the VHD
# Returns: 0 if mounted, 1 if not mounted
wsl_is_vhd_mounted() {
    local uuid="$1"
    local mountpoint_check
    
    if [[ -z "$uuid" ]]; then
        log_error "UUID is required"
        return 2
    fi
    
    # Validate UUID format for security
    if ! validate_uuid "$uuid"; then
        log_error "Invalid UUID format"
        return 2
    fi
    
    log_debug "lsblk -f -J | jq --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .mountpoints[]' | grep -v 'null'"
    mountpoint_check=$(lsblk -f -J | jq --arg UUID "$uuid" "$JQ_GET_MOUNTPOINTS_BY_UUID" 2>/dev/null | grep -v "null")
    
    if [[ -n "$mountpoint_check" ]]; then
        return 0  # VHD is mounted
    else
        return 1  # VHD is not mounted
    fi
}

# Get VHD device information
# Args: $1 - UUID of the VHD
# Prints device information to stdout
wsl_get_vhd_info() {
    local uuid="$1"
    local device_name fsavail fsuse mountpoints
    
    if [[ -z "$uuid" ]]; then
        log_error "UUID is required"
        return 1
    fi
    
    log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
    device_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
    fsavail=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_FSAVAIL_BY_UUID" 2>/dev/null)
    fsuse=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_FSUSE_BY_UUID" 2>/dev/null)
    mountpoints=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_MOUNTPOINTS_BY_UUID" 2>/dev/null)
    
    if [[ -n "$device_name" ]]; then
        echo "  Device: /dev/$device_name"
        echo "  Available: ${fsavail:-N/A}"
        echo "  Used: ${fsuse:-N/A}"
        echo "  Mounted at: ${mountpoints:-<not mounted>}"
        return 0
    else
        echo "  No device information available"
        return 1
    fi
}

# Get the mount point for a VHD by UUID
# Args: $1 - UUID of the VHD
# Returns: Mount point path (empty if not mounted)
wsl_get_vhd_mount_point() {
    local uuid="$1"
    
    if [[ -z "$uuid" ]]; then
        log_error "UUID is required"
        return 1
    fi
    
    log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .mountpoints[]' | grep -v 'null' | head -n 1"
    
    local mount_point=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_MOUNTPOINTS_BY_UUID" 2>/dev/null | grep -v "null" | head -n 1)
    
    echo "$mount_point"
    return 0
}

# Attach a VHD to WSL
# Args: $1 - VHD path (Windows path format)
#       $2 - Variable name to store error output (optional)
# Returns: 0 on success, 1 on failure
# Note: Attaches with --bare flag only (no --name parameter)
# If $2 is provided, error output will be stored in that variable
wsl_attach_vhd() {
    local vhd_path="$1"
    local error_output_var="$2"
    local error_output=""
    
    if [[ -z "$vhd_path" ]]; then
        log_error "VHD path is required"
        return 1
    fi
    
    # Validate inputs for security
    if ! validate_windows_path "$vhd_path"; then
        log_error "Invalid VHD path format"
        return 1
    fi
    
    if [[ -n "$error_output_var" ]]; then
        # Capture error output for caller to inspect
        error_output=$(wsl.exe --mount --vhd "$vhd_path" --bare 2>&1)
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            return 0
        else
            # Store error output in the provided variable name
            eval "$error_output_var=\"\$error_output\""
            return 1
        fi
    else
        # Normal mode: suppress output
        if debug_cmd wsl.exe --mount --vhd "$vhd_path" --bare >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

# Detach a VHD from WSL
# Args: $1 - VHD path (Windows path format)
#       $2 - UUID (optional, for history tracking)
#       $3 - Device name (optional, for history tracking)
# Returns: 0 on success, 1 on failure
# Note: WSL unmounts VHDs by their original file path
wsl_detach_vhd() {
    local vhd_path="$1"
    local uuid="$2"  # UUID for history tracking
    local dev_name="$3"  # Optional device name for history tracking
    
    if [[ -z "$vhd_path" ]]; then
        log_error "VHD path is required"
        return 1
    fi
    
    # Save detach event to history before detaching (if UUID provided)
    if [[ -n "$uuid" ]]; then
        save_detach_history "$vhd_path" "$uuid" "$dev_name"
    fi
    
    # WSL unmounts by the VHD file path that was originally used to mount
    # Use timeout to prevent hanging (30 seconds max)
    local error_output
    if command -v timeout >/dev/null 2>&1; then
        error_output=$(timeout "${DETACH_TIMEOUT:-30}" wsl.exe --unmount "$vhd_path" 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            return 0
        elif [[ $exit_code -eq 124 ]]; then
            # Timeout occurred
            log_debug "WSL unmount timed out after 30 seconds"
            log_warn "WSL unmount operation timed out. The VHD may still be detaching."
            return 1
        else
            # Other error
            log_debug "WSL unmount failed: $error_output"
            return 1
        fi
    else
        # No timeout command available, try without it
        if debug_cmd wsl.exe --unmount "$vhd_path" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

# Mount a VHD by UUID to a mount point
# Args: $1 - UUID of the VHD
#       $2 - Mount point path
# Returns: 0 on success, 1 on failure
# Create a mount point directory (primitive operation)
# Generic Linux operation - not WSL-specific
# Args: $1 - Mount point path
# Returns: 0 on success, 1 on failure
create_mount_point() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        log_error "Mount point path is required"
        return 1
    fi
    
    if [[ ! -d "$mount_point" ]]; then
        if debug_cmd mkdir -p "$mount_point" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    return 0  # Already exists
}

# Mount a filesystem by UUID (primitive operation)
# Generic Linux operation - not WSL-specific
# Args: $1 - UUID of the filesystem
#       $2 - Mount point path
# Returns: 0 on success, 1 on failure
mount_filesystem() {
    local uuid="$1"
    local mount_point="$2"
    
    if [[ -z "$uuid" || -z "$mount_point" ]]; then
        log_error "UUID and mount point are required"
        return 1
    fi
    
    # Validate inputs for security
    if ! validate_uuid "$uuid"; then
        log_error "Invalid UUID format"
        return 1
    fi
    
    if ! validate_mount_point "$mount_point"; then
        log_error "Invalid mount point format"
        return 1
    fi
    
    # Check sudo permissions before attempting mount
    if ! check_sudo_permissions; then
        log_error "Cannot mount filesystem: sudo permissions required"
        return 1
    fi
    
    # Use safe_sudo wrapper for mount operation
    if safe_sudo mount UUID="$uuid" "$mount_point" >/dev/null 2>&1; then
        return 0
    else
        log_error "Failed to mount filesystem UUID=$uuid to $mount_point"
        return 1
    fi
}

# Mount VHD with comprehensive error handling and setup
# WSL-specific helper that creates mount point and mounts filesystem
# Args: $1 - UUID of the VHD
#       $2 - Mount point path
# Returns: 0 on success, 1 on failure
wsl_mount_vhd() {
    local uuid="$1"
    local mount_point="$2"
    
    if [[ -z "$uuid" || -z "$mount_point" ]]; then
        echo "Error: UUID and mount point are required" >&2
        return 1
    fi
    
    # Create mount point if it doesn't exist
    if ! create_mount_point "$mount_point"; then
        log_error "Failed to create mount point: $mount_point"
        return 1
    fi
    
    # Mount the filesystem
    if ! mount_filesystem "$uuid" "$mount_point"; then
        log_error "Failed to mount filesystem"
        return 1
    fi
    
    return 0
}

# Unmount a filesystem from a mount point (primitive operation)
# Generic Linux operation - not WSL-specific
# Args: $1 - Mount point path
# Returns: 0 on success, 1 on failure
umount_filesystem() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        echo "Error: Mount point is required" >&2
        return 1
    fi
    
    # Check sudo permissions before attempting unmount
    if ! check_sudo_permissions; then
        log_error "Cannot unmount filesystem: sudo permissions required"
        return 1
    fi
    
    # Use safe_sudo wrapper for umount operation
    if safe_sudo umount "$mount_point" >/dev/null 2>&1; then
        return 0
    else
        log_error "Failed to unmount filesystem from $mount_point"
        return 1
    fi
}

# Unmount VHD with comprehensive error handling and diagnostics
# WSL-specific helper that provides detailed error messages and diagnostics
# if the unmount fails (e.g., processes using the mount point)
# Args: $1 - Mount point path
# Returns: 0 on success, 1 on failure
wsl_umount_vhd() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        echo "Error: Mount point is required" >&2
        return 1
    fi
    
    # Attempt to unmount using primitive operation
    if umount_filesystem "$mount_point"; then
        return 0
    else
        # Unmount failed - provide diagnostics
        log_error "Failed to unmount VHD"
        log_info "Tip: Make sure no processes are using the mount point"
        log_info "Checking for processes using the mount point:"
        log_debug "sudo lsof +D $mount_point"
        # Use safe_sudo for lsof (non-critical diagnostic command)
        if check_sudo_permissions; then
            safe_sudo lsof +D "$mount_point" 2>/dev/null || log_info "  No processes found (or lsof not available)"
        else
            log_info "  Cannot check processes (sudo permissions required)"
        fi
        log_info "You can try to force unmount with: sudo umount -l $mount_point"
        return 1
    fi
}

# Complete mount operation: attach VHD if needed and mount to filesystem
# Args: $1 - VHD path (Windows path format)
#       $2 - UUID of the VHD
#       $3 - Mount point path
#       $4 - VHD name (optional)
# Returns: 0 on success, 1 on failure
wsl_complete_mount() {
    local vhd_path="$1"
    local uuid="$2"
    local mount_point="$3"
    
    if [[ -z "$vhd_path" || -z "$uuid" || -z "$mount_point" ]]; then
        echo "Error: VHD path, UUID, and mount point are required" >&2
        return 1
    fi
    
    # Check if already attached
    if ! wsl_is_vhd_attached "$uuid"; then
        # Attach VHD (no name parameter - uses --bare flag only)
        if ! wsl_attach_vhd "$vhd_path"; then
            return 1
        fi
        sleep "${SLEEP_AFTER_ATTACH:-2}"  # Give system time to recognize the device
    fi
    
    # Check if already mounted
    if ! wsl_is_vhd_mounted "$uuid"; then
        # Mount VHD
        if ! wsl_mount_vhd "$uuid" "$mount_point"; then
            return 1
        fi
    fi
    
    return 0
}

# Complete unmount operation: unmount from filesystem and detach from WSL
# Args: $1 - VHD path (Windows path format)
#       $2 - UUID of the VHD
#       $3 - Mount point path
# Returns: 0 on success, 1 on failure
wsl_complete_unmount() {
    local vhd_path="$1"
    local uuid="$2"
    local mount_point="$3"
    
    if [[ -z "$vhd_path" || -z "$uuid" || -z "$mount_point" ]]; then
        echo "Error: VHD path, UUID, and mount point are required" >&2
        return 1
    fi
    
    # Check if attached
    if ! wsl_is_vhd_attached "$uuid"; then
        return 0  # Nothing to do
    fi
    
    # Unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$uuid"; then
        if ! wsl_umount_vhd "$mount_point"; then
            return 1
        fi
    fi
    
    # Get device name from tracking file for history
    local dev_name=""
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        local normalized_path=$(normalize_vhd_path "$vhd_path")
        dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
    fi
    
    # Detach from WSL
    if ! wsl_detach_vhd "$vhd_path" "$uuid" "$dev_name"; then
        log_warn "Failed to detach VHD before deletion. It may still be attached."
        return 1
    fi
    
    return 0
}

# Get list of block device names
# Returns: Array of block device names
wsl_get_block_devices() {
    log_debug "sudo lsblk -J | jq -r '.blockdevices[].name'"
    local output
    output=$(safe_sudo_capture lsblk -J 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get block device list: sudo permissions required"
        return 1
    fi
    echo "$output" | jq -r "$JQ_GET_ALL_DEVICE_NAMES"
}

# Get list of all disk UUIDs
# Returns: Array of UUIDs
wsl_get_disk_uuids() {
    log_debug "sudo blkid -s UUID -o value"
    local output
    output=$(safe_sudo_capture blkid -s UUID -o value 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get disk UUIDs: sudo permissions required"
        return 1
    fi
    echo "$output"
}

# Find UUID by mount point
# Args: $1 - Mount point path
# Returns: UUID if found, empty string if not found
wsl_find_uuid_by_mountpoint() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        return 1
    fi
    
    # Validate mount point format for security
    if ! validate_mount_point "$mount_point"; then
        return 1
    fi
    
    # Get UUID for the device mounted at the specified mount point
    log_debug "lsblk -f -J | jq -r --arg MP '$mount_point' '.blockdevices[] | select(.mountpoints != null and .mountpoints != []) | select(.mountpoints[] == \$MP) | .uuid' | grep -v 'null' | head -n 1"
    local uuid=$(lsblk -f -J | jq -r --arg MP "$mount_point" "$JQ_GET_UUID_BY_MOUNTPOINT" 2>/dev/null | grep -v "null" | head -n 1)
    
    if [[ -n "$uuid" ]]; then
        echo "$uuid"
        return 0
    fi
    
    return 1
}

# Count the number of dynamically attached VHDs (non-system disks)
# Returns: Count of non-system disks (sd[d-z])
# Note: This is used for safety checks before UUID discovery
wsl_count_dynamic_vhds() {
    local all_uuids
    all_uuids=$(wsl_get_disk_uuids)
    local count=0
    
    while IFS= read -r uuid; do
        [[ -z "$uuid" ]] && continue
        
        log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
        local dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        
        if [[ -n "$dev_name" ]]; then
            # Count dynamically attached disks (usually sd[d-z] and multi-character variants like sdaa, sdab)
            # Skip system disks (sda, sdb, sdc)
            # Pattern matches: sd[d-z] followed by zero or more lowercase letters (e.g., sdd, sde, sdaa, sdab)
            if [[ "$dev_name" =~ ^sd[d-z][a-z]*$ ]]; then
                ((count++))
            fi
        fi
    done <<< "$all_uuids"
    
    echo "$count"
    return 0
}

# Find UUID by checking all attached VHDs for one matching pattern
# ⚠️ UNSAFE: Only use when wsl_count_dynamic_vhds() returns exactly 1
# This looks for dynamically attached VHDs (typically sd[d-z])
# Returns: First non-system disk UUID found, empty if none
# WARNING: With multiple VHDs attached, this returns arbitrary result
wsl_find_dynamic_vhd_uuid() {
    local all_uuids
    all_uuids=$(wsl_get_disk_uuids)
    
    while IFS= read -r uuid; do
        [[ -z "$uuid" ]] && continue
        
        log_debug "lsblk -f -J | jq -r --arg UUID '$uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'"
        local dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" "$JQ_GET_DEVICE_NAME_BY_UUID" 2>/dev/null)
        
        if [[ -n "$dev_name" ]]; then
            # Look for dynamically attached disks (usually sd[d-z] and multi-character variants like sdaa, sdab)
            # Skip system disks (sda, sdb, sdc)
            # Pattern matches: sd[d-z] followed by zero or more lowercase letters (e.g., sdd, sde, sdaa, sdab)
            if [[ "$dev_name" =~ ^sd[d-z][a-z]*$ ]]; then
                echo "$uuid"
                return 0
            fi
        fi
    done <<< "$all_uuids"
    
    return 1
}

# Find UUID of an attached VHD by verifying path exists with multi-VHD safety
# Args: $1 - VHD path (Windows format)
# Returns: 0 with UUID if single VHD attached, 1 if not found, 2 if multiple VHDs (ambiguous)
# Note: SAFE implementation - checks tracking file first (by path and name), fails explicitly with multiple VHDs instead of guessing
wsl_find_uuid_by_path() {
    local vhd_path_win="$1"
    
    if [[ -z "$vhd_path_win" ]]; then
        return 1
    fi
    
    # Validate path format for security
    if ! validate_windows_path "$vhd_path_win"; then
        return 1
    fi
    
    # First, try to lookup UUID from tracking file by path
    local tracked_uuid=$(lookup_vhd_uuid "$vhd_path_win")
    if [[ -n "$tracked_uuid" ]]; then
        # Verify the UUID is actually attached
        if wsl_is_vhd_attached "$tracked_uuid"; then
            echo "$tracked_uuid"
            return 0
        else
            # UUID in tracking file but not attached - tracking file is stale
            log_debug "Tracked UUID not attached, falling back to discovery"
        fi
    fi
    
    # Second, try to lookup UUID by device name (extract dev_name from tracking file first)
    local normalized_path=$(normalize_vhd_path "$vhd_path_win")
    local tracked_dev_name=$(jq -r --arg path "$normalized_path" "$JQ_GET_DEV_NAME_BY_PATH" "$DISK_TRACKING_FILE" 2>/dev/null)
    if [[ -n "$tracked_dev_name" && "$tracked_dev_name" != "null" ]]; then
        local uuid_by_dev_name=$(lookup_vhd_uuid_by_dev_name "$tracked_dev_name")
        if [[ -n "$uuid_by_dev_name" ]]; then
            # Verify the UUID is actually attached
            if wsl_is_vhd_attached "$uuid_by_dev_name"; then
                log_debug "Found UUID by dev_name '$tracked_dev_name': $uuid_by_dev_name"
                echo "$uuid_by_dev_name"
                return 0
            fi
        fi
    fi
    
    # Convert Windows path to WSL path to check if VHD file exists
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path_win")
    
    # Check if VHD file exists
    if [[ ! -e "$vhd_path_wsl" ]]; then
        return 1
    fi
    
    # Count non-system disks for safety check
    local count=$(wsl_count_dynamic_vhds)
    
    if [[ $count -gt 1 ]]; then
        # Multiple VHDs attached - cannot safely determine which one
        log_error "Multiple VHDs attached ($count found). Cannot determine UUID from path alone."
        log_info "Please specify --uuid explicitly or use 'status --all' to see all UUIDs."
        return 2
    elif [[ $count -eq 0 ]]; then
        # No VHDs attached
        return 1
    else
        # Safe: exactly one dynamic VHD attached
        wsl_find_dynamic_vhd_uuid
    fi
}

# Handle UUID discovery result with consistent error handling
# This function standardizes the error handling pattern used across command functions
# when discovering UUIDs via wsl_find_uuid_by_path()
# Args: $1 - Discovery result (exit code from wsl_find_uuid_by_path: 0=found, 1=not found, 2=multiple VHDs)
#       $2 - Discovered UUID (may be empty)
#       $3 - Context message (e.g., "mount", "umount", "attach") for error messages
#       $4 - Path (for error messages, optional)
# Returns: 0 if UUID is valid, exits with error otherwise
# Note: This function EXITS on errors (for use in command functions)
#       For helper functions that need to return error codes, handle discovery results manually
handle_uuid_discovery_result() {
    local discovery_result="$1"
    local uuid="$2"
    local context="$3"
    local path="${4:-}"
    
    if [[ $discovery_result -eq 2 ]]; then
        # Multiple VHDs detected - cannot safely determine which one
        local script_name="${0##*/}"
        local multi_vhd_help="Multiple VHDs are attached. Use one of:
  1. View all attached VHDs: $script_name status --all
  2. Detach other VHDs first, then retry
  3. Use explicit UUID if known: $script_name $context --path $path --uuid <UUID>"
        
        if [[ "$QUIET" == "true" ]]; then
            echo "ambiguous: multiple VHDs"
        fi
        
        error_exit "Cannot determine UUID: Multiple VHDs are attached" 1 "$multi_vhd_help"
    elif [[ $discovery_result -ne 0 ]] || [[ -z "$uuid" ]]; then
        # UUID not found or discovery failed
        local script_name="${0##*/}"
        local not_found_help="Could not detect UUID for $context operation.
The VHD file exists but is not attached to WSL.

Suggestions:
  1. Attach the VHD first: $script_name attach --path $path
  2. Check if VHD is attached: $script_name status --all
  3. Verify the path is correct"
        
        if [[ "$QUIET" == "true" ]]; then
            echo "uuid not found"
        fi
        
        error_exit "Could not detect UUID of VHD" 1 "$not_found_help"
    else
        # UUID found and valid
        log_info "Discovered UUID: $uuid"
        return 0
    fi
}

# Check if a device exists in the system (regardless of formatting)
# Args: $1 - Device name (e.g., sdd, sde) - /dev/ prefix optional
# Returns: 0 if device exists, 1 if not found
# Note: This checks device existence only, not whether it has a filesystem
wsl_device_exists() {
    local device_name="$1"
    
    if [[ -z "$device_name" ]]; then
        return 1
    fi
    
    # Remove /dev/ prefix if present
    device_name="${device_name#/dev/}"
    
    # Validate device name format for security
    if ! validate_device_name "$device_name"; then
        log_debug "wsl_device_exists: invalid device name format"
        return 1
    fi
    
    # Check if device exists in lsblk output (regardless of UUID/filesystem)
    log_debug "lsblk -J | jq -r --arg DEVICE '$device_name' '.blockdevices[] | select(.name == \$DEVICE) | .name'"
    local found_device=$(lsblk -J 2>/dev/null | jq -r --arg DEVICE "$device_name" '.blockdevices[] | select(.name == $DEVICE) | .name' 2>/dev/null | head -n 1)
    
    if [[ -n "$found_device" && "$found_device" == "$device_name" ]]; then
        return 0
    fi
    
    return 1
}

# Get UUID from device name using lsblk
# This is used in the device-first detection approach: after detecting a new device,
# this function retrieves its UUID if the device is formatted
# Args: $1 - Device name (e.g., sdd, sde, or /dev/sdd)
# Returns: UUID if found, empty string if not found (device is unformatted)
# Exit code: 0 if found, 1 if not found
# Note: Device must exist and have a filesystem UUID (be formatted) to return a UUID
wsl_get_uuid_by_device() {
    local device_name="$1"
    
    if [[ -z "$device_name" ]]; then
        return 1
    fi
    
    # Remove /dev/ prefix if present
    device_name="${device_name#/dev/}"
    
    # Validate device name format for security
    if ! validate_device_name "$device_name"; then
        log_debug "wsl_get_uuid_by_device: invalid device name format"
        return 1
    fi
    
    log_debug "lsblk -f -J | jq -r --arg DEVICE '$device_name' '.blockdevices[] | select(.name == \$DEVICE) | .uuid'"
    local uuid=$(lsblk -f -J | jq -r --arg DEVICE "$device_name" '.blockdevices[] | select(.name == $DEVICE) | .uuid' 2>/dev/null | grep -v "null" | head -n 1)
    
    if [[ -n "$uuid" && "$uuid" != "null" && "$uuid" != "" ]]; then
        echo "$uuid"
        return 0
    fi
    
    return 1
}

# Detect new device name after attach using snapshot-based detection
# This function uses device-first detection which works for both formatted and unformatted VHDs
# Args: $1 - Array name containing old device names (optional, for backward compatibility)
#       $2... - Old device names as separate arguments (preferred method for reliability)
#             Example: detect_new_device_after_attach "" "sdd" "sde" 
#             Or: detect_new_device_after_attach "old_devs" (uses nameref, less reliable)
# Returns: Device name of newly attached disk via stdout, empty string if not found
# Exit code: 0 if device found, 1 if not found
# Note: 
#   - Filters old devices to only include dynamically attached VHDs (sd[d-z] pattern) BEFORE sleep
#   - Excludes system disks (sda, sdb, sdc) to avoid false positives
#   - Includes sleep delay (configurable via SLEEP_AFTER_ATTACH) for kernel device recognition
#   - Only returns devices matching sd[d-z] pattern (dynamically attached VHDs)
detect_new_device_after_attach() {
    local old_devs_array_name="$1"
    shift  # Remove first argument
    local old_devs=("$@")  # Get remaining arguments as array
    
    # If no arguments provided (except array name), try to use array name or capture current state
    if [[ ${#old_devs[@]} -eq 0 ]]; then
        if [[ -n "$old_devs_array_name" ]]; then
            # Use provided array via nameref (more reliable than indirect reference)
            # This requires bash 4.3+ for nameref support
            declare -n array_ref="$old_devs_array_name"
            old_devs=("${array_ref[@]}")
            unset -n array_ref  # Unset nameref to avoid side effects
            log_debug "Received old_devs array via nameref (count: ${#old_devs[@]}): ${old_devs[*]}"
        else
            # Capture current state (should be called before attach)
            old_devs=($(wsl_get_block_devices))
            log_debug "Captured old_devs array directly (count: ${#old_devs[@]}): ${old_devs[*]}"
        fi
    else
        log_debug "Received old_devs array as arguments (count: ${#old_devs[@]}): ${old_devs[*]}"
    fi
    
    # Filter old devices to only include dynamically attached VHDs (non-system disks)
    # This MUST be done BEFORE the sleep to ensure we're using the pre-attach state
    # This ensures we only compare relevant devices and avoid false positives
    declare -A old_vhd_devs
    log_debug "Filtering old devices (count: ${#old_devs[@]}): ${old_devs[*]}"
    local dev
    for dev in "${old_devs[@]}"; do
        [[ -z "$dev" ]] && continue
        
        # Only include dynamically attached VHDs (sd[d-z] pattern)
        # Skip system disks (sda, sdb, sdc)
        if [[ "$dev" =~ ^sd[d-z][a-z]*$ ]]; then
            old_vhd_devs["$dev"]=1
            log_debug "Old VHD device: $dev"
        fi
    done
    log_debug "Filtered old VHD devices (count: ${#old_vhd_devs[@]}): ${!old_vhd_devs[*]}"
    
    # Give kernel time to recognize the newly attached device
    sleep "${SLEEP_AFTER_ATTACH:-2}"
    
    # Get new devices after attach
    local new_devs=($(wsl_get_block_devices))
    
    # Find the new device (one that wasn't in the old filtered list)
    # CRITICAL: Only return devices that are dynamically attached VHDs (non-system disks)
    # System disks (sda, sdb, sdc) should be excluded to avoid false positives
    log_debug "Comparing devices: old_vhd_devs has ${#old_vhd_devs[@]} devices, new_devs has ${#new_devs[@]} devices"
    for dev in "${new_devs[@]}"; do
        [[ -z "$dev" ]] && continue
        
        # Check if this device was in the old filtered list
        if [[ -z "${old_vhd_devs[$dev]:-}" ]]; then
            # This device is new - verify it's a dynamically attached VHD
            # Only return device if it's a dynamically attached VHD (sd[d-z] pattern)
            # Skip system disks (sda, sdb, sdc)
            if [[ "$dev" =~ ^sd[d-z][a-z]*$ ]]; then
                log_debug "New VHD device detected: $dev (not in old snapshot)"
                echo "$dev"
                return 0
            else
                log_debug "Skipping device $dev - not a dynamically attached VHD"
            fi
        else
            log_debug "Device $dev already in old snapshot (skipping - was present before attach)"
        fi
    done
    
    # No new device found
    log_debug "No new VHD device detected"
    return 1
}

# Format an attached VHD with a filesystem
# Args: $1 - Device name (e.g., sdd) or full path (e.g., /dev/sdd)
#       $2 - Filesystem type (optional, defaults to ext4)
# Returns: UUID of formatted device on success, empty string on failure
# Note: VHD must be attached to WSL before formatting
format_vhd() {
    local device="$1"
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    local fs_type="${2:-$default_fs}"
    
    if [[ -z "$device" ]]; then
        log_error "Device is required"
        return 1
    fi
    
    # Validate filesystem type for security
    if ! validate_filesystem_type "$fs_type"; then
        log_error "Invalid filesystem type: $fs_type"
        return 1
    fi
    
    # Extract device name if full path provided
    local device_name="$device"
    if [[ "$device" =~ ^/dev/ ]]; then
        device_name="${device#/dev/}"
    fi
    
    # Validate device name format for security
    if ! validate_device_name "$device_name"; then
        log_error "Invalid device name format: $device_name"
        return 1
    fi
    
    # Normalize device path (add /dev/ if not present)
    if [[ ! "$device" =~ ^/dev/ ]]; then
        device="/dev/$device"
    fi
    
    # Verify device exists
    if [[ ! -b "$device" ]]; then
        log_error "Device $device does not exist or is not a block device"
        return 1
    fi
    
    # Check sudo permissions before formatting
    if ! check_sudo_permissions; then
        log_error "Cannot format device: sudo permissions required"
        return 1
    fi
    
    # Format the device using safe_sudo wrapper
    if ! safe_sudo mkfs -t "$fs_type" "$device" >/dev/null 2>&1; then
        log_error "Failed to format device $device with $fs_type"
        return 1
    fi
    
    sleep 1  # Give system time to update UUID info
    
    # Get the UUID of the newly formatted device using safe_sudo_capture
    log_debug "sudo blkid -s UUID -o value $device"
    local new_uuid
    new_uuid=$(safe_sudo_capture blkid -s UUID -o value "$device" 2>/dev/null)
    
    if [[ -z "$new_uuid" ]]; then
        log_error "Could not retrieve UUID after formatting"
        return 1
    fi
    
    # Output the UUID
    echo "$new_uuid"
    return 0
}

# Delete a VHD file
# Args: $1 - VHD path (Windows path format)
# Returns: 0 on success, 1 on failure
# Note: VHD must be detached before deletion. This function only deletes the file.
wsl_delete_vhd() {
    local vhd_path_win="$1"
    
    if [[ -z "$vhd_path_win" ]]; then
        log_error "VHD path is required"
        return 1
    fi
    
    # Convert Windows path to WSL path for file operations
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path_win")
    
    # Check if VHD file exists
    if [[ ! -e "$vhd_path_wsl" ]]; then
        log_error "VHD file does not exist at $vhd_path_wsl"
        return 1
    fi
    
    # Delete the VHD file
    if debug_cmd rm -f "$vhd_path_wsl" 2>/dev/null; then
        return 0
    else
        log_error "Failed to delete VHD file"
        return 1
    fi
}

# Create a new VHD file and format it
# Args: $1 - VHD path (Windows path format, e.g., C:/path/to/disk.vhdx)
#       $2 - Size (e.g., 1G, 500M, 10G)
#       $3 - Filesystem type (optional, defaults to ext4)
# Returns: 0 on success, 1 on failure
# Prints: The UUID of the newly created and formatted disk
wsl_create_vhd() {
    local vhd_path_win="$1"
    local size="$2"
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    local fs_type="${3:-$default_fs}"
    
    if [[ -z "$vhd_path_win" || -z "$size" ]]; then
        log_error "VHD path and size are required"
        return 1
    fi
    
    # Convert Windows path to WSL path for file operations
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path_win")
    
    # Check if VHD already exists
    if [[ -e "$vhd_path_wsl" ]]; then
        log_error "VHD file already exists at $vhd_path_wsl"
        return 1
    fi
    
    # Create parent directory if it doesn't exist
    local vhd_dir=$(dirname "$vhd_path_wsl")
    if [[ ! -d "$vhd_dir" ]]; then
        if ! debug_cmd mkdir -p "$vhd_dir" 2>/dev/null; then
            log_error "Failed to create directory $vhd_dir"
            return 1
        fi
    fi
    
    # Ensure qemu-img is installed (check for common package managers)
    if ! command -v qemu-img &> /dev/null; then
        log_error "qemu-img is not installed. Please install it first."
        log_info "  Arch/Manjaro: sudo pacman -Sy qemu-img"
        log_info "  Ubuntu/Debian: sudo apt install qemu-utils"
        log_info "  Fedora: sudo dnf install qemu-img"
        return 1
    fi
    
    # Take snapshot of current block devices before attach
    # This is used to detect the newly attached device after attach
    local old_devs=($(wsl_get_block_devices))
    
    # Create the VHD file
    if ! debug_cmd qemu-img create -f vhdx "$vhd_path_wsl" "$size" >/dev/null 2>&1; then
        log_error "Failed to create VHD file"
        return 1
    fi
    
    # Attach the VHD to WSL (no name parameter - uses --bare flag only)
    if ! wsl_attach_vhd "$vhd_path_win"; then
        log_error "Failed to attach VHD to WSL"
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    # Detect new device using snapshot-based detection
    # This uses the centralized helper function for consistency
    local new_dev
    new_dev=$(detect_new_device_after_attach "" "${old_devs[@]}")
    
    if [[ -z "$new_dev" ]]; then
        log_error "Could not detect newly attached device"
        wsl_detach_vhd "$vhd_path_win" "" ""
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    # Format the new device using helper function
    local new_uuid=$(format_vhd "$new_dev" "$fs_type")
    if [[ $? -ne 0 || -z "$new_uuid" ]]; then
        log_error "Failed to format device /dev/$new_dev with $fs_type"
        wsl_detach_vhd "$vhd_path_win" "" ""
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    # Save mapping to tracking file with device name
    save_vhd_mapping "$vhd_path_win" "$new_uuid" "" "$new_dev"
    
    # Output the UUID
    echo "$new_uuid"
    return 0
}

# ============================================================================
# RESOURCE CLEANUP FUNCTIONS - Automatic cleanup on script failure/interrupt
# ============================================================================
# All cleanup functions are WSL-specific and consolidated here

# Global cleanup tracking arrays
# These track resources that need cleanup on script exit/interrupt
declare -a CLEANUP_VHDS  # Format: "path|uuid|name" for each VHD
declare -a CLEANUP_FILES  # Format: file paths

# Flag to track if cleanup system is initialized
CLEANUP_INITIALIZED="${CLEANUP_INITIALIZED:-false}"

# Initialize resource cleanup system
# Sets up trap handlers for EXIT, INT, and TERM signals
# Should be called once at the start of main scripts
init_resource_cleanup() {
    if [[ "$CLEANUP_INITIALIZED" == "true" ]]; then
        return 0  # Already initialized
    fi
    
    # Set trap handler for cleanup on exit/interrupt
    trap cleanup_on_exit EXIT INT TERM
    
    CLEANUP_INITIALIZED="true"
    log_debug "Resource cleanup system initialized"
    return 0
}

# Register a VHD for cleanup tracking
# Args: $1 - VHD path (Windows format)
#       $2 - UUID (optional, for detach operations)
#       $3 - Device name (optional, for detach operations)
# Returns: 0 on success, 1 on failure
register_vhd_cleanup() {
    local vhd_path="$1"
    local uuid="${2:-}"
    local dev_name="${3:-}"
    
    if [[ -z "$vhd_path" ]]; then
        log_debug "register_vhd_cleanup: vhd_path is empty"
        return 1
    fi
    
    # Validate path format for security
    if ! validate_windows_path "$vhd_path"; then
        log_debug "register_vhd_cleanup: invalid path format"
        return 1
    fi
    
    # Validate UUID if provided
    if [[ -n "$uuid" ]] && ! validate_uuid "$uuid"; then
        log_debug "register_vhd_cleanup: invalid UUID format"
        return 1
    fi
    
    # Check if already registered (avoid duplicates)
    local entry="$vhd_path|$uuid|$dev_name"
    for existing in "${CLEANUP_VHDS[@]}"; do
        if [[ "$existing" == "$entry" ]]; then
            log_debug "VHD already registered for cleanup: $vhd_path"
            return 0  # Already registered
        fi
    done
    
    # Add to cleanup array
    CLEANUP_VHDS+=("$entry")
    log_debug "Registered VHD for cleanup: $vhd_path (UUID: ${uuid:-<none>}, Device: ${dev_name:-<none>})"
    return 0
}

# Unregister a VHD from cleanup tracking
# Args: $1 - VHD path (Windows format)
# Returns: 0 on success, 1 if not found
unregister_vhd_cleanup() {
    local vhd_path="$1"
    
    if [[ -z "$vhd_path" ]]; then
        log_debug "unregister_vhd_cleanup: vhd_path is empty"
        return 1
    fi
    
    # Validate path format for security
    if ! validate_windows_path "$vhd_path"; then
        log_debug "unregister_vhd_cleanup: invalid path format"
        return 1
    fi
    
    # Find and remove from array
    local new_array=()
    local found=0
    for entry in "${CLEANUP_VHDS[@]}"; do
        if [[ "$entry" =~ ^"$vhd_path"\| ]]; then
            found=1
            log_debug "Unregistered VHD from cleanup: $vhd_path"
        else
            new_array+=("$entry")
        fi
    done
    
    CLEANUP_VHDS=("${new_array[@]}")
    
    if [[ $found -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Register a file for cleanup tracking
# Args: $1 - File path
# Returns: 0 on success, 1 on failure
register_file_cleanup() {
    local file_path="$1"
    
    if [[ -z "$file_path" ]]; then
        log_debug "register_file_cleanup: file_path is empty"
        return 1
    fi
    
    # Check if already registered (avoid duplicates)
    for existing in "${CLEANUP_FILES[@]}"; do
        if [[ "$existing" == "$file_path" ]]; then
            log_debug "File already registered for cleanup: $file_path"
            return 0  # Already registered
        fi
    done
    
    # Add to cleanup array
    CLEANUP_FILES+=("$file_path")
    log_debug "Registered file for cleanup: $file_path"
    return 0
}

# Unregister a file from cleanup tracking
# Args: $1 - File path
# Returns: 0 on success, 1 if not found
unregister_file_cleanup() {
    local file_path="$1"
    
    if [[ -z "$file_path" ]]; then
        log_debug "unregister_file_cleanup: file_path is empty"
        return 1
    fi
    
    # Find and remove from array
    local new_array=()
    local found=0
    for entry in "${CLEANUP_FILES[@]}"; do
        if [[ "$entry" == "$file_path" ]]; then
            found=1
            log_debug "Unregistered file from cleanup: $file_path"
        else
            new_array+=("$entry")
        fi
    done
    
    CLEANUP_FILES=("${new_array[@]}")
    
    if [[ $found -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Cleanup function called on script exit/interrupt
# Detaches VHDs and removes temporary files that were registered for cleanup
cleanup_on_exit() {
    local exit_code=$?
    local cleanup_needed=0
    
    # Check if there are any resources to clean up
    if [[ ${#CLEANUP_VHDS[@]} -gt 0 ]] || [[ ${#CLEANUP_FILES[@]} -gt 0 ]]; then
        cleanup_needed=1
    fi
    
    if [[ $cleanup_needed -eq 0 ]]; then
        return $exit_code  # Nothing to clean up
    fi
    
    # Only show cleanup messages if not in quiet mode or if DEBUG is enabled
    if [[ "$QUIET" != "true" ]] || [[ "$DEBUG" == "true" ]]; then
        echo >&2
        echo -e "${YELLOW}[!] Cleaning up resources on exit...${NC}" >&2
    fi
    
    # Clean up VHDs (detach from WSL)
    for entry in "${CLEANUP_VHDS[@]}"; do
        if [[ -z "$entry" ]]; then
            continue
        fi
        
        # Parse entry: "path|uuid|dev_name"
        IFS='|' read -r vhd_path uuid dev_name <<< "$entry"
        
        if [[ -z "$vhd_path" ]]; then
            continue
        fi
        
        # Validate path before using
        if ! validate_windows_path "$vhd_path"; then
            log_debug "Skipping invalid VHD path in cleanup: $vhd_path"
            continue
        fi
        
        # Attempt to detach VHD (suppress errors in cleanup)
        if [[ "$QUIET" != "true" ]] || [[ "$DEBUG" == "true" ]]; then
            echo -e "${YELLOW}  Detaching VHD: $vhd_path${NC}" >&2
        fi
        
        # Attempt detach (suppress errors - cleanup should be best-effort)
        wsl_detach_vhd "$vhd_path" "$uuid" "$dev_name" >/dev/null 2>&1 || true
    done
    
    # Clean up temporary files
    for file_path in "${CLEANUP_FILES[@]}"; do
        if [[ -z "$file_path" ]]; then
            continue
        fi
        
        if [[ -f "$file_path" ]]; then
            if [[ "$QUIET" != "true" ]] || [[ "$DEBUG" == "true" ]]; then
                echo -e "${YELLOW}  Removing file: $file_path${NC}" >&2
            fi
            rm -f "$file_path" 2>/dev/null || true
        fi
    done
    
    # Clear cleanup arrays
    CLEANUP_VHDS=()
    CLEANUP_FILES=()
    
    if [[ "$QUIET" != "true" ]] || [[ "$DEBUG" == "true" ]]; then
        echo -e "${GREEN}[✓] Cleanup complete${NC}" >&2
    fi
    
    return $exit_code
}

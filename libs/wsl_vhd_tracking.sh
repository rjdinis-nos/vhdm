#!/bin/bash

# WSL VHD Tracking File Management Library
# This file contains all functions for managing the persistent VHD tracking file
# All tracking file operations follow the standardized naming pattern: tracking_file_<action>_<what>()

# Source configuration file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
if [[ -f "$PARENT_DIR/config.sh" ]]; then
    source "$PARENT_DIR/config.sh"
fi

# Source utility functions for validation and logging (if not already sourced)
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
tracking_file_init() {
    local dir=$(dirname "$DISK_TRACKING_FILE")
    
    if [[ ! -d "$dir" ]]; then
        if [[ "$DEBUG" == "true" ]]; then
            log_debug "Executing: mkdir -p $dir"
        fi
        if mkdir -p "$dir" 2>/dev/null; then
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
#   This ensures we only skip tracking when actually running tests
is_test_vhd() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    local normalized=$(normalize_vhd_path "$path")
    
    # Only skip tracking if WSL_DISKS_DIR is set (from .env.test) and path is within it
    # This ensures we only skip tracking when actually running tests
    # We don't use filename patterns because legitimate VHDs may have "test" in their names
    if [[ -n "${WSL_DISKS_DIR:-}" ]]; then
        local test_dir_normalized=$(normalize_vhd_path "$WSL_DISKS_DIR")
        if [[ "$normalized" == "$test_dir_normalized"* ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Save path→UUID mapping to tracking file
# Args: $1 - VHD path (Windows format)
#       $2 - UUID
#       $3 - Mount point (optional, can be empty or comma-separated list)
#       $4 - Device name (optional, e.g., sde, sdd)
# Returns: 0 on success, 1 on failure
tracking_file_save_mapping() {
    local path="$1"
    local uuid="$2"
    local mount_points="$3"
    local dev_name="${4:-}"
    
    if [[ -z "$path" || -z "$uuid" ]]; then
        log_debug "tracking_file_save_mapping: path or uuid is empty"
        return 1
    fi
    
    # Validate inputs for security
    if ! validate_windows_path "$path"; then
        log_debug "tracking_file_save_mapping: invalid path format"
        return 1
    fi
    
    if ! validate_uuid "$uuid"; then
        log_debug "tracking_file_save_mapping: invalid UUID format"
        return 1
    fi
    
    if [[ -n "$dev_name" ]] && ! validate_device_name "$dev_name"; then
        log_debug "tracking_file_save_mapping: invalid device name format"
        return 1
    fi
    
    tracking_file_init || return 1
    
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
tracking_file_lookup_uuid_by_path() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    # Validate path format for security
    if ! validate_windows_path "$path"; then
        return 1
    fi
    
    tracking_file_init || return 1
    
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
tracking_file_lookup_uuid_by_dev_name() {
    local dev_name="$1"
    
    if [[ -z "$dev_name" ]]; then
        return 1
    fi
    
    # Validate device name format for security
    if ! validate_device_name "$dev_name"; then
        return 1
    fi
    
    tracking_file_init || return 1
    
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

# Update tracking file with mount point (helper for mount operations)
# This function handles both --vhd-path and --dev-name cases
# Args: $1 - vhd_path (optional)
#       $2 - dev_name (optional)
#       $3 - uuid (required)
#       $4 - mount_point (required)
#       $5 - found_path (optional, will be looked up if not provided and dev_name is set)
# Returns: 0 on success, 1 on failure
tracking_file_update_mount_point() {
    local vhd_path="$1"
    local dev_name="$2"
    local uuid="$3"
    local mount_point="$4"
    local found_path="$5"
    
    if [[ -z "$uuid" || -z "$mount_point" ]]; then
        log_debug "tracking_file_update_mount_point: uuid and mount_point are required"
        return 1
    fi
    
    if [[ -n "$vhd_path" ]]; then
        # Update mount points list in tracking file
        if tracking_file_update_mount_points "$vhd_path" "$mount_point"; then
            log_debug "Updated mount point in tracking file: $vhd_path → $mount_point"
            return 0
        else
            log_debug "Failed to update mount point in tracking file for $vhd_path"
            return 1
        fi
    elif [[ -n "$dev_name" ]]; then
        # vhd_path not provided, but we have device name
        # Check if UUID exists in tracking file and update mount point
        # Note: found_path was already determined in Scenario 2 if --dev-name was used
        log_debug "Checking for path in tracking file (found_path='$found_path')"
        if [[ -z "$found_path" ]] && [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            # Find VHD path associated with this UUID
            found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
            log_debug "Looked up path from UUID: found_path='$found_path'"
        fi
        
        if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
            # UUID exists in tracking file - update mount point
            log_debug "Updating tracking file for UUID $uuid (path: $found_path): mount_point=$mount_point"
            if tracking_file_update_mount_points "$found_path" "$mount_point"; then
                log_debug "Successfully updated mount point in tracking file: $found_path → $mount_point"
                return 0
            else
                log_debug "Failed to update mount point in tracking file for $found_path"
                return 1
            fi
        else
            log_debug "No path found in tracking file for UUID $uuid - cannot update mount point"
            return 1
        fi
    fi
    
    return 1
}

# Remove mount point from tracking file (helper for unmount operations)
# This function handles UUID, mount point, vhd_path, or dev_name cases
# Args: $1 - vhd_path (optional)
#       $2 - dev_name (optional)
#       $3 - uuid (required)
#       $4 - mount_point (optional, if not provided, clears all mount points)
#       $5 - found_path (optional, will be looked up if not provided)
# Returns: 0 on success, 1 on failure
tracking_file_remove_mount_point() {
    local vhd_path="$1"
    local dev_name="$2"
    local uuid="$3"
    local mount_point="$4"
    local found_path="$5"
    
    if [[ -z "$uuid" ]]; then
        log_debug "tracking_file_remove_mount_point: uuid is required"
        return 1
    fi
    
    # Find VHD path if not provided
    if [[ -z "$vhd_path" ]]; then
        # Try to find path from UUID in tracking file
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            found_path=$(jq -r --arg uuid "$uuid" "$JQ_GET_PATH_BY_UUID" "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
            if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                vhd_path="$found_path"
                log_debug "Found VHD path from UUID: $vhd_path"
            fi
        fi
    fi
    
    if [[ -n "$vhd_path" ]]; then
        # Clear mount point in tracking file (empty string clears it)
        if tracking_file_update_mount_points "$vhd_path" ""; then
            log_debug "Cleared mount point in tracking file: $vhd_path"
            return 0
        else
            log_debug "Failed to clear mount point in tracking file for $vhd_path"
            return 1
        fi
    elif [[ -n "$dev_name" ]]; then
        # vhd_path not found, but we have device name
        # Try to find path from device name in tracking file
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            # Find VHD path associated with this device name
            local normalized_dev_name="$dev_name"
            found_path=$(jq -r --arg dev_name "$normalized_dev_name" '.mappings | to_entries[] | select(.value.dev_name == $dev_name) | .key' "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
            if [[ -n "$found_path" && "$found_path" != "null" && "$found_path" != "" ]]; then
                log_debug "Found VHD path from device name: $found_path"
                if tracking_file_update_mount_points "$found_path" ""; then
                    log_debug "Cleared mount point in tracking file: $found_path"
                    return 0
                else
                    log_debug "Failed to clear mount point in tracking file for $found_path"
                    return 1
                fi
            fi
        fi
        log_debug "No path found in tracking file for device name $dev_name - cannot clear mount point"
        return 1
    else
        log_debug "No vhd_path or dev_name provided - cannot clear mount point"
        return 1
    fi
}

# Update mount points for a VHD in tracking file
# Args: $1 - VHD path (Windows format)
#       $2 - Mount points (comma-separated list, empty to clear)
# Returns: 0 on success, 1 on failure
tracking_file_update_mount_points() {
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
    
    tracking_file_init || return 1
    
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
tracking_file_remove_mapping() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    tracking_file_init || return 1
    
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
tracking_file_save_detach_history() {
    local path="$1"
    local uuid="$2"
    local dev_name="${3:-}"
    
    if [[ -z "$path" || -z "$uuid" ]]; then
        log_debug "tracking_file_save_detach_history: path or uuid is empty"
        return 1
    fi
    
    # Skip tracking for test-related VHDs
    if is_test_vhd "$path"; then
        log_debug "Skipping detach history save for test VHD: $path"
        return 0
    fi
    
    tracking_file_init || return 1
    
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

# Remove detach history entry for a VHD path
# Called when a VHD is re-attached to clean up stale history
# Args: $1 - VHD path (Windows format)
# Returns: 0 on success, 1 on failure
tracking_file_remove_detach_history() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        log_debug "tracking_file_remove_detach_history: path is empty"
        return 1
    fi
    
    # Skip tracking for test-related VHDs
    if is_test_vhd "$path"; then
        log_debug "Skipping detach history removal for test VHD: $path"
        return 0
    fi
    
    tracking_file_init || return 1
    
    local normalized=$(normalize_vhd_path "$path")
    
    # Create secure temporary file using mktemp
    local temp_file
    temp_file=$(mktemp "${DISK_TRACKING_FILE}.tmp.XXXXXX" 2>/dev/null)
    if [[ $? -ne 0 || -z "$temp_file" ]]; then
        log_debug "Failed to create temporary file"
        return 1
    fi
    
    # Set up trap handler to clean up temp file on exit/interrupt
    trap "rm -f '$temp_file'" EXIT INT TERM
    
    # Ensure jq is available
    if ! command -v jq &> /dev/null; then
        log_debug "jq not available, skipping detach history removal"
        rm -f "$temp_file"
        trap - EXIT INT TERM
        return 1
    fi
    
    # Remove all detach history entries for this path
    log_debug "Removing detach history entries for: $normalized"
    
    if jq --arg path "$normalized" \
          "$JQ_REMOVE_DETACH_HISTORY_BY_PATH" \
          "$DISK_TRACKING_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$DISK_TRACKING_FILE"
        trap - EXIT INT TERM
        log_debug "Removed detach history entries for: $normalized"
        return 0
    else
        rm -f "$temp_file"
        trap - EXIT INT TERM
        log_debug "Failed to remove detach history entries"
        return 1
    fi
}

# Get detach history from tracking file
# Args: $1 - Number of entries to retrieve (optional, default: 10, max: 50)
# Returns: JSON array of detach events, most recent first
tracking_file_get_detach_history() {
    local default_limit="${DEFAULT_HISTORY_LIMIT:-10}"
    local max_limit="${MAX_HISTORY_LIMIT:-50}"
    local limit="${1:-$default_limit}"
    
    # Limit to max entries
    if [[ $limit -gt $max_limit ]]; then
        limit=$max_limit
    fi
    
    tracking_file_init || return 1
    
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
tracking_file_get_last_detach_for_path() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    tracking_file_init || return 1
    
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




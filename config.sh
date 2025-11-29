#!/bin/bash

# ============================================================================
# WSL VHD Disk Management - Configuration File
# ============================================================================
# This file contains all configuration variables used across the disk
# management scripts. Modify values here to customize behavior.
#
# Variables can be overridden via environment variables before sourcing this
# file, or by exporting them in your shell session.
#
# ----------------------------------------------------------------------------
# Understanding the ${VAR:-default} Syntax
# ----------------------------------------------------------------------------
# This configuration file uses bash parameter expansion syntax:
#
#   ${VAR:-default}
#
# This syntax means: "Use the value of VAR if it is set and non-empty,
# otherwise use 'default'."
#
# How it works:
#   - If VAR is unset or empty: Uses the default value (after the :-)
#   - If VAR is set and non-empty: Uses the value of VAR
#
# Examples:
#   export DEFAULT_VHD_NAME="${DEFAULT_VHD_NAME:-disk}"
#     - If DEFAULT_VHD_NAME is already set: Uses that value
#     - If DEFAULT_VHD_NAME is unset/empty: Uses "disk"
#
#   export MAX_PATH_LENGTH="${MAX_PATH_LENGTH:-4096}"
#     - If MAX_PATH_LENGTH is already set: Uses that value
#     - If MAX_PATH_LENGTH is unset/empty: Uses 4096
#
# This allows you to:
#   1. Set defaults in this file
#   2. Override them via environment variables before sourcing this file
#   3. Override them in your shell: export DEFAULT_VHD_NAME="mydisk"
#   4. Override them inline: DEFAULT_VHD_NAME="mydisk" ./vhdm.sh ...
#
# ----------------------------------------------------------------------------
# ============================================================================

# ============================================================================
# UI/DISPLAY CONFIGURATION
# ============================================================================
# Terminal output colors for status messages and logging

export GREEN='\033[0;32m'      # Success messages
export YELLOW='\033[1;33m'      # Warning messages
export RED='\033[0;31m'        # Error messages
export BLUE='\033[0;34m'       # Info/debug messages
export CYAN='\033[0;36m'       # Additional info messages
export NC='\033[0m'            # No Color (reset)

# ============================================================================
# DEFAULT VALUES
# ============================================================================
# Default values used when command-line options are not provided

# Note: VHD name parameter has been removed. Device names (dev_name) are now used for tracking.

# Default VHD size for create command (used when --size is not specified)
# Format: number followed by unit (K, M, G, T) with optional B
# Examples: 1G, 500M, 10GB
export DEFAULT_VHD_SIZE="${DEFAULT_VHD_SIZE:-1G}"

# Default filesystem type for format command (used when --type is not specified)
# Allowed values: ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat
export DEFAULT_FILESYSTEM_TYPE="${DEFAULT_FILESYSTEM_TYPE:-ext4}"

# Default history limit for history command (number of detach events to show)
export DEFAULT_HISTORY_LIMIT="${DEFAULT_HISTORY_LIMIT:-10}"

# ============================================================================
# VALIDATION LIMITS
# ============================================================================
# Maximum values enforced during input validation to prevent security issues

# Maximum path length (prevents buffer overflow issues)
export MAX_PATH_LENGTH="${MAX_PATH_LENGTH:-4096}"

# Maximum size string length (e.g., "10GB" = 4 characters)
export MAX_SIZE_STRING_LENGTH="${MAX_SIZE_STRING_LENGTH:-20}"

# Note: MAX_VHD_NAME_LENGTH removed - device names are used for tracking instead

# Maximum device name length (e.g., "sda", "sdaa")
export MAX_DEVICE_NAME_LENGTH="${MAX_DEVICE_NAME_LENGTH:-10}"

# Maximum history limit (enforced maximum for history command)
export MAX_HISTORY_LIMIT="${MAX_HISTORY_LIMIT:-50}"

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================
# System-level settings for disk tracking, caching, and logging

# Location of the persistent disk tracking file that stores VHD path→UUID mappings
# Default: ~/.config/vhdm/vhd_mapping.json
export DISK_TRACKING_FILE="${DISK_TRACKING_FILE:-$HOME/.config/vhdm/vhd_tracking.json}"

# lsblk cache TTL (time-to-live) in seconds
# Used for caching lsblk output to reduce system calls
export LSBLK_CACHE_TTL="${LSBLK_CACHE_TTL:-2}"

# Optional log file path (set via LOG_FILE environment variable)
# If empty, logging to file is disabled
# Example: export LOG_FILE="/var/log/wsl-disk-management.log"
export LOG_FILE="${LOG_FILE:-}"

# Sleep delay after attaching VHD (in seconds)
# Gives the kernel time to recognize the newly attached device
# Default: 2 seconds
export SLEEP_AFTER_ATTACH="${SLEEP_AFTER_ATTACH:-2}"

# Timeout for VHD detach operations (in seconds)
# Used when unmounting VHDs to prevent hanging operations
# Default: 30 seconds
export DETACH_TIMEOUT="${DETACH_TIMEOUT:-30}"

# Automatic sync of mappings on startup
# When enabled, removes stale mappings (detached VHDs) from tracking file
# on every vhdm.sh invocation. This keeps the tracking file accurate.
# Set to "false" to disable automatic sync (use 'sync' command manually)
# Default: true
export AUTO_SYNC_MAPPINGS="${AUTO_SYNC_MAPPINGS:-true}"

# ============================================================================
# RUNTIME BEHAVIOR
# ============================================================================
# Runtime flags that control script behavior (can be overridden by command-line options)

# Quiet mode flag (minimal output, machine-readable format)
export QUIET="${QUIET:-false}"

# Debug mode flag (show all commands before execution)
export DEBUG="${DEBUG:-false}"

# ============================================================================
# JQ QUERY TEMPLATES
# ============================================================================
# Complex jq query expressions used for JSON processing
# These are stored as strings and used with jq --arg parameters at runtime

# Mapping operations (tracking file)
export JQ_SAVE_MAPPING='.mappings[$path] = {uuid: $uuid, last_attached: $ts, mount_points: $mp, dev_name: $dev_name}'
export JQ_GET_UUID_BY_PATH='.mappings[$path].uuid // empty'
export JQ_CHECK_MAPPING_EXISTS='.mappings[$path] // empty'
export JQ_UPDATE_MOUNT_POINTS='.mappings[$path].mount_points = $mp'
export JQ_DELETE_MAPPING='del(.mappings[$path])'
export JQ_GET_DEV_NAME_BY_PATH='.mappings[$path].dev_name // empty'
export JQ_GET_PATH_BY_UUID='.mappings | to_entries[] | select(.value.uuid == $uuid) | .key'
export JQ_GET_DEV_NAME_BY_UUID='.mappings | to_entries[] | select(.value.uuid == $uuid) | .value.dev_name // empty'
export JQ_GET_PATH_BY_DEV_NAME='.mappings | to_entries[] | select(.value.dev_name == $dev_name) | .key'

# Detach history operations
export JQ_SAVE_DETACH_HISTORY='.detach_history = ([{path: $path, uuid: $uuid, dev_name: $dev_name, timestamp: $ts}] + (.detach_history // [])) | .detach_history |= .[0:50]'
export JQ_GET_DETACH_HISTORY='.detach_history // [] | .[0:$limit]'
export JQ_GET_LAST_DETACH_BY_PATH='.detach_history // [] | map(select(.path == $path)) | .[0] // empty'
export JQ_REMOVE_DETACH_HISTORY_BY_PATH='.detach_history = (.detach_history // [] | map(select(.path != $path)))'

# Block device operations (lsblk)
export JQ_CHECK_UUID_EXISTS='.blockdevices[] | select(.uuid == $UUID) | .uuid'
export JQ_GET_MOUNTPOINTS_BY_UUID='.blockdevices[] | select(.uuid == $UUID) | .mountpoints[]'
export JQ_GET_DEVICE_NAME_BY_UUID='.blockdevices[] | select(.uuid == $UUID) | .name'
export JQ_GET_FSAVAIL_BY_UUID='.blockdevices[] | select(.uuid == $UUID) | .fsavail'
export JQ_GET_FSUSE_BY_UUID='.blockdevices[] | select(.uuid == $UUID) | ."fsuse%"'
export JQ_GET_UUID_BY_MOUNTPOINT='.blockdevices[] | select(.mountpoints != null and .mountpoints != []) | select(.mountpoints[] == $MP) | .uuid'

# Block device list operations
export JQ_GET_ALL_DEVICE_NAMES='.blockdevices[].name'

# History display operations
export JQ_FORMAT_HISTORY_ENTRY='.[] | "Path: \(.path)\n" + "UUID: \(.uuid)\n" + (if .dev_name and .dev_name != "" then "Device: \(.dev_name)\n" else "" end) + "Timestamp: \(.timestamp)\n"'

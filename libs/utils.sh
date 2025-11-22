#!/bin/bash

# Utility functions for disk management scripts

# Source configuration file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
if [[ -f "$PARENT_DIR/config.sh" ]]; then
    source "$PARENT_DIR/config.sh"
fi

# Source colors if not already defined (for logging - fallback if config.sh not found)
if [[ -z "${GREEN:-}" ]]; then
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export RED='\033[0;31m'
    export BLUE='\033[0;34m'
    export NC='\033[0m' # No Color
fi

# ============================================================================
# INPUT VALIDATION FUNCTIONS - Security: Prevent Command Injection
# ============================================================================

# Validate Windows path format and reject dangerous patterns
# Args: $1 - Windows path to validate
# Returns: 0 if valid, 1 if invalid
# Security: Prevents command injection and path traversal
validate_windows_path() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    # Reject empty strings
    [[ -z "$path" ]] && return 1
    
    # Must start with drive letter (A-Z) followed by colon and forward/backslash
    if [[ ! "$path" =~ ^[A-Za-z]:[/\\] ]]; then
        return 1
    fi
    
    # Reject command injection attempts - dangerous characters
    # Store pattern in variable to avoid quoting issues with backtick
    local dangerous_chars='[`$();|&<>"'"'"'*?\[\]!~]'
    if [[ "$path" =~ $dangerous_chars ]]; then
        return 1
    fi
    
    # Reject directory traversal attempts
    if [[ "$path" =~ \.\. ]]; then
        return 1
    fi
    
    # Reject newlines and control characters
    if [[ "$path" =~ [[:cntrl:]] ]]; then
        return 1
    fi
    
    # Reject paths that are too long (prevent buffer issues)
    local max_length="${MAX_PATH_LENGTH:-4096}"
    if [[ ${#path} -gt $max_length ]]; then
        return 1
    fi
    
    return 0
}

# Validate UUID format (RFC 4122)
# Args: $1 - UUID to validate
# Returns: 0 if valid, 1 if invalid
# Security: Ensures UUID matches expected format before use
validate_uuid() {
    local uuid="$1"
    
    if [[ -z "$uuid" ]]; then
        return 1
    fi
    
    # UUID format: 8-4-4-4-12 hexadecimal digits
    # Example: 550e8400-e29b-41d4-a716-446655440000
    if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        return 1
    fi
    
    # Reject any additional characters (prevent injection)
    if [[ ${#uuid} -ne 36 ]]; then
        return 1
    fi
    
    return 0
}

# Validate mount point path
# Args: $1 - Mount point path to validate
# Returns: 0 if valid, 1 if invalid
# Security: Prevents command injection and path traversal
validate_mount_point() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        return 1
    fi
    
    # Must be absolute path starting with /
    if [[ ! "$mount_point" =~ ^/ ]]; then
        return 1
    fi
    
    # Reject command injection attempts
    # Store pattern in variable to avoid quoting issues with backtick
    local dangerous_chars='[`$();|&<>"'"'"'*?\[\]!~]'
    if [[ "$mount_point" =~ $dangerous_chars ]]; then
        return 1
    fi
    
    # Reject directory traversal attempts
    if [[ "$mount_point" =~ \.\. ]]; then
        return 1
    fi
    
    # Reject newlines and control characters
    if [[ "$mount_point" =~ [[:cntrl:]] ]]; then
        return 1
    fi
    
    # Reject paths that are too long
    local max_length="${MAX_PATH_LENGTH:-4096}"
    if [[ ${#mount_point} -gt $max_length ]]; then
        return 1
    fi
    
    # Reject paths with spaces at start/end (could be injection attempts)
    if [[ "$mount_point" =~ ^[[:space:]] ]] || [[ "$mount_point" =~ [[:space:]]$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate device name (e.g., sdd, sde, sdaa)
# Args: $1 - Device name to validate
# Returns: 0 if valid, 1 if invalid
# Security: Ensures device name matches expected pattern
validate_device_name() {
    local device="$1"
    
    if [[ -z "$device" ]]; then
        return 1
    fi
    
    # Device name pattern: sd followed by one or more lowercase letters
    # Examples: sda, sdb, sdd, sde, sdaa, sdab, etc.
    if [[ ! "$device" =~ ^sd[a-z]+$ ]]; then
        return 1
    fi
    
    # Reject if too long (unlikely to be valid)
    local max_length="${MAX_DEVICE_NAME_LENGTH:-10}"
    if [[ ${#device} -gt $max_length ]]; then
        return 1
    fi
    
    return 0
}

# Validate VHD name (WSL mount name)
# Args: $1 - VHD name to validate
# Returns: 0 if valid, 1 if invalid
# Security: Prevents command injection in WSL mount names
validate_vhd_name() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        return 1
    fi
    
    # VHD name should be alphanumeric with underscores and hyphens
    # Reject dangerous characters
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    # Reject if too long
    local max_length="${MAX_VHD_NAME_LENGTH:-64}"
    if [[ ${#name} -gt $max_length ]]; then
        return 1
    fi
    
    # Reject if starts/ends with special characters
    if [[ "$name" =~ ^[-_] ]] || [[ "$name" =~ [-_]$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate size string format
# Args: $1 - Size string to validate (e.g., "5G", "500M")
# Returns: 0 if valid, 1 if invalid
# Security: Ensures size string matches expected format
validate_size_string() {
    local size="$1"
    
    if [[ -z "$size" ]]; then
        return 1
    fi
    
    # Pattern: number (with optional decimal) followed by optional unit
    # Units: K, M, G, T (case insensitive) with optional B
    if [[ ! "$size" =~ ^[0-9]+(\.[0-9]+)?[KMGT]?[B]?$ ]]; then
        return 1
    fi
    
    # Reject if too long
    local max_length="${MAX_SIZE_STRING_LENGTH:-20}"
    if [[ ${#size} -gt $max_length ]]; then
        return 1
    fi
    
    # Extract number and validate it's reasonable
    local num=$(echo "$size" | sed 's/[^0-9.]//g')
    if [[ -z "$num" ]]; then
        return 1
    fi
    
    # Reject negative numbers (though regex should catch this)
    if [[ "$num" =~ ^- ]]; then
        return 1
    fi
    
    return 0
}

# Validate filesystem type
# Args: $1 - Filesystem type to validate
# Returns: 0 if valid, 1 if invalid
# Security: Whitelist of allowed filesystem types
validate_filesystem_type() {
    local fs_type="$1"
    
    if [[ -z "$fs_type" ]]; then
        return 1
    fi
    
    # Whitelist of allowed filesystem types
    case "$fs_type" in
        ext2|ext3|ext4|xfs|btrfs|ntfs|vfat|exfat)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Sanitize string for safe use in commands (additional safety layer)
# Args: $1 - String to sanitize
# Returns: Sanitized string via stdout
# Security: Removes or escapes dangerous characters
sanitize_string() {
    local input="$1"
    
    if [[ -z "$input" ]]; then
        return 0
    fi
    
    # Remove control characters
    echo "$input" | tr -d '\000-\037\177-\237'
}

# ============================================================================
# LOGGING FUNCTIONS - Structured logging with levels
# ============================================================================

# Log level constants
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Optional log file (set via LOG_FILE environment variable)
LOG_FILE="${LOG_FILE:-}"

# Get timestamp for log entries
_get_log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Internal logging function
# Args: $1 - Log level (DEBUG, INFO, WARN, ERROR)
#       $2 - Message
_log_internal() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(_get_log_timestamp)
    local log_entry="[$timestamp] [$level] $message"
    
    # Always write to stderr (unless quiet mode for INFO/DEBUG)
    case "$level" in
        DEBUG)
            if [[ "$DEBUG" == "true" ]]; then
                echo -e "${BLUE}$log_entry${NC}" >&2
            fi
            ;;
        INFO)
            if [[ "$QUIET" != "true" ]]; then
                echo "$log_entry" >&2
            fi
            ;;
        WARN)
            if [[ "$QUIET" != "true" ]]; then
                echo -e "${YELLOW}$log_entry${NC}" >&2
            fi
            ;;
        ERROR)
            # Errors always shown, even in quiet mode
            echo -e "${RED}$log_entry${NC}" >&2
            ;;
    esac
    
    # Write to log file if configured
    if [[ -n "$LOG_FILE" ]] && [[ "$level" != "DEBUG" || "$DEBUG" == "true" ]]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Log debug message (only shown when DEBUG=true)
# Args: $@ - Message
log_debug() {
    _log_internal "DEBUG" "$@"
}

# Log info message (shown unless QUIET=true)
# Args: $@ - Message
log_info() {
    _log_internal "INFO" "$@"
}

# Log warning message (shown unless QUIET=true)
# Args: $@ - Message
log_warn() {
    _log_internal "WARN" "$@"
}

# Log error message (always shown, even in quiet mode)
# Args: $@ - Message
log_error() {
    _log_internal "ERROR" "$@"
}

# Log success message (info level with green color)
# Args: $@ - Message
log_success() {
    if [[ "$QUIET" != "true" ]]; then
        local timestamp=$(_get_log_timestamp)
        local log_entry="[$timestamp] [INFO] $*"
        echo -e "${GREEN}$log_entry${NC}" >&2
        
        # Write to log file if configured
        if [[ -n "$LOG_FILE" ]]; then
            echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi
}

# Helper function to calculate total size of files in directory (in bytes)
# Args: $1 - Directory path
# Returns: Size in bytes
get_directory_size_bytes() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "0"
        return 1
    fi
    
    # Use du to get size in bytes (--bytes or -b)
    local size_bytes
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} du -sb '$dir' | awk '{print \$1}'" >&2
    fi
    size_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$size_bytes" ]]; then
        echo "0"
        return 1
    fi
    
    echo "$size_bytes"
    return 0
}

# Helper function to convert size string to bytes
# Args: $1 - Size string (e.g., "5G", "500M", "10G")
# Returns: Size in bytes
convert_size_to_bytes() {
    local size_str="$1"
    local num=$(echo "$size_str" | sed 's/[^0-9.]//g')
    local unit=$(echo "$size_str" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')
    
    # Remove decimal point for bash arithmetic
    local num_int=$(echo "$num" | cut -d. -f1)
    [[ -z "$num_int" ]] && num_int=0
    
    case "$unit" in
        K|KB)
            echo $((num_int * 1024))
            ;;
        M|MB)
            echo $((num_int * 1024 * 1024))
            ;;
        G|GB)
            echo $((num_int * 1024 * 1024 * 1024))
            ;;
        T|TB)
            echo $((num_int * 1024 * 1024 * 1024 * 1024))
            ;;
        *)
            # Assume bytes if no unit
            echo "$num_int"
            ;;
    esac
}

# Helper function to convert bytes to human readable format
# Args: $1 - Size in bytes
# Returns: Human readable size string
bytes_to_human() {
    local bytes="$1"
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt $((1024 * 1024)) ]]; then
        echo "$((bytes / 1024))KB"
    elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
        echo "$((bytes / (1024 * 1024)))MB"
    else
        echo "$((bytes / (1024 * 1024 * 1024)))GB"
    fi
}

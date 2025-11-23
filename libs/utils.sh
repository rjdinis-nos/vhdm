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

# ============================================================================
# CENTRALIZED ERROR HANDLING FUNCTIONS
# ============================================================================

# Error exit function for command-level functions
# Command functions should exit on errors (not return)
# Args: $1 - Error message
#       $2 - Exit code (default: 1)
#       $3 - Additional help text (optional)
# Exits: With specified exit code (default: 1)
error_exit() {
    local msg="$1"
    local code="${2:-1}"
    local help_text="${3:-}"
    
    # Always log error (even in quiet mode)
    log_error "$msg"
    
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

# Error return function for helper functions
# Helper functions should return error codes (not exit)
# Args: $1 - Error message
#       $2 - Return code (default: 1)
# Returns: With specified return code (default: 1)
error_return() {
    local msg="$1"
    local code="${2:-1}"
    
    # Log error (always shown, even in quiet mode)
    log_error "$msg"
    
    return "$code"
}

# Print a standardized section header
# Args: $1 - Section title (optional, defaults to empty)
# Note: Respects QUIET mode - only prints in non-quiet mode
# Example: print_section_header "VHD Disk Mount Operation"
print_section_header() {
    local title="${1:-}"
    
    # Only print in non-quiet mode
    if [[ "$QUIET" != "true" ]]; then
        log_info "========================================"
        if [[ -n "$title" ]]; then
            log_info "  $title"
            log_info "========================================"
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

# ============================================================================
# PATH CONVERSION FUNCTIONS - Convert Windows paths to WSL paths
# ============================================================================

# Convert Windows path to WSL path format
# Args: $1 - Windows path (e.g., C:/path/to/file.vhdx or C:\path\to\file.vhdx)
# Returns: WSL path via stdout (e.g., /mnt/c/path/to/file.vhdx)
# Example: wsl_convert_path "C:/VMs/disk.vhdx" -> "/mnt/c/VMs/disk.vhdx"
wsl_convert_path() {
    local win_path="$1"
    
    if [[ -z "$win_path" ]]; then
        return 1
    fi
    
    # Convert drive letter to lowercase and prepend /mnt/
    # Convert backslashes to forward slashes
    echo "$win_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g'
}

# ============================================================================
# SUDO VALIDATION FUNCTIONS - Security: Validate sudo permissions
# ============================================================================

# Check if sudo is available and user has permissions
# Returns: 0 if sudo is available and user has permissions, 1 otherwise
# Security: Validates sudo availability before operations
check_sudo_permissions() {
    # Check if sudo command exists
    if ! command -v sudo &>/dev/null; then
        log_error "sudo command not found. Please install sudo or run as root."
        return 1
    fi
    
    # Check if user can run sudo (test with a harmless command)
    # Use -n flag to avoid password prompt if not cached
    if ! sudo -n true 2>/dev/null; then
        # If -n fails, try with password prompt (but this will hang if no TTY)
        # Instead, just check if sudo is configured
        if ! sudo -v 2>/dev/null; then
            log_error "Cannot verify sudo permissions. Please ensure you have sudo access."
            log_info "You may need to run 'sudo -v' to cache your credentials first."
            return 1
        fi
    fi
    
    return 0
}

# Safe sudo wrapper that validates permissions and command success
# Args: $@ - Command and arguments to run with sudo
# Returns: 0 on success, 1 on failure
# Security: Validates sudo permissions and command execution
# Note: For commands that need output, use safe_sudo_capture() instead
#       Caller should redirect stdout/stderr as needed (e.g., >/dev/null 2>&1)
safe_sudo() {
    local cmd="$1"
    shift
    local args=("$@")
    local error_output
    local exit_code
    local temp_stderr
    
    # Check sudo permissions first
    if ! check_sudo_permissions; then
        return 1
    fi
    
    # Execute sudo command
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "Executing: sudo $cmd ${args[*]}"
    fi
    
    # Create temporary file for stderr capture
    temp_stderr=$(mktemp /tmp/safe_sudo_stderr.XXXXXX 2>/dev/null)
    if [[ $? -ne 0 || -z "$temp_stderr" ]]; then
        # Fallback: execute directly and capture all output
        error_output=$(sudo "$cmd" "${args[@]}" 2>&1)
        exit_code=$?
    else
        # Execute command, capturing stderr to temp file
        # stdout passes through (caller can redirect)
        sudo "$cmd" "${args[@]}" 2>"$temp_stderr"
        exit_code=$?
        error_output=$(cat "$temp_stderr" 2>/dev/null)
        rm -f "$temp_stderr"
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        # Command failed - provide detailed error message
        log_error "sudo command failed: $cmd ${args[*]}"
        if [[ -n "$error_output" ]]; then
            log_error "Error output: $error_output"
        fi
        
        # Provide helpful suggestions based on common failures
        if [[ "$cmd" == "mount" ]] || [[ "$cmd" == "umount" ]]; then
            log_info "Mount/unmount operations require sudo privileges."
            log_info "Please ensure you have sudo access and the necessary permissions."
        elif [[ "$cmd" == "mkfs" ]]; then
            log_info "Formatting operations require sudo privileges."
            log_info "Please ensure you have sudo access and the necessary permissions."
        fi
        
        return 1
    fi
    
    return 0
}

# Safe sudo wrapper for commands that need output capture
# Args: $@ - Command and arguments to run with sudo
# Returns: Command output via stdout, exit code via return value
# Security: Validates sudo permissions before execution
# Note: Use this for commands that need their output (e.g., blkid, lsblk)
safe_sudo_capture() {
    local cmd="$1"
    shift
    local args=("$@")
    local output
    local exit_code
    
    # Check sudo permissions first
    if ! check_sudo_permissions; then
        return 1
    fi
    
    if [[ "$DEBUG" == "true" ]]; then
        log_debug "Executing: sudo $cmd ${args[*]}"
    fi
    
    # Execute command and capture output
    output=$(sudo "$cmd" "${args[@]}" 2>&1)
    exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        # Command failed - log error but don't print output (may contain sensitive info)
        log_error "sudo command failed: $cmd ${args[*]}"
        if [[ "$DEBUG" == "true" ]] && [[ -n "$output" ]]; then
            log_debug "Error output: $output"
        fi
        return 1
    fi
    
    # Success - output the result
    echo "$output"
    return 0
}

# ============================================================================
# RESOURCE CLEANUP FUNCTIONS - Automatic cleanup on script failure/interrupt
# ============================================================================

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
#       $3 - VHD name (optional, for detach operations)
# Returns: 0 on success, 1 on failure
register_vhd_cleanup() {
    local vhd_path="$1"
    local uuid="${2:-}"
    local vhd_name="${3:-}"
    
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
    local entry="$vhd_path|$uuid|$vhd_name"
    for existing in "${CLEANUP_VHDS[@]}"; do
        if [[ "$existing" == "$entry" ]]; then
            log_debug "VHD already registered for cleanup: $vhd_path"
            return 0  # Already registered
        fi
    done
    
    # Add to cleanup array
    CLEANUP_VHDS+=("$entry")
    log_debug "Registered VHD for cleanup: $vhd_path (UUID: ${uuid:-<none>}, Name: ${vhd_name:-<none>})"
    return 0
}

# Unregister a VHD from cleanup tracking
# Args: $1 - VHD path (Windows format)
# Returns: 0 on success, 1 if not found
unregister_vhd_cleanup() {
    local vhd_path="$1"
    
    if [[ -z "$vhd_path" ]]; then
        return 1
    fi
    
    # Validate path format for security
    if ! validate_windows_path "$vhd_path"; then
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
        
        # Parse entry: "path|uuid|name"
        IFS='|' read -r vhd_path uuid vhd_name <<< "$entry"
        
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
        
        # Source wsl_helpers.sh if available (for wsl_detach_vhd function)
        if ! command -v wsl_detach_vhd &>/dev/null; then
            # Try to source wsl_helpers.sh
            # Use BASH_SOURCE to get the actual file location, not SCRIPT_DIR which may be overwritten
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            local wsl_helpers_path="$script_dir/wsl_helpers.sh"
            # Double-check the path is correct (should be libs/wsl_helpers.sh)
            if [[ -f "$wsl_helpers_path" ]] && [[ "$wsl_helpers_path" == */libs/wsl_helpers.sh ]]; then
                source "$wsl_helpers_path" 2>/dev/null || true
            fi
        fi
        
        # Attempt detach (suppress errors - cleanup should be best-effort)
        if command -v wsl_detach_vhd &>/dev/null; then
            wsl_detach_vhd "$vhd_path" "$uuid" "$vhd_name" >/dev/null 2>&1 || true
        else
            # Fallback: try wsl.exe directly
            wsl.exe --unmount "$vhd_path" >/dev/null 2>&1 || true
        fi
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

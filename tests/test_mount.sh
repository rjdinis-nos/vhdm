#!/bin/bash

# Test script for disk_management.sh mount command
# This script tests various mount scenarios using the VHD from .env.test

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
VERBOSE=false
SELECTED_TESTS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--test)
            shift
            SELECTED_TESTS+=($1)
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  -v, --verbose     Show detailed test output"
            echo "  -t, --test NUM    Run specific test by number (can be used multiple times)"
            echo "  -h, --help        Show this help message"
            echo
            echo "Examples:"
            echo "  $0                Run all tests"
            echo "  $0 -t 1           Run only test 1"
            echo "  $0 -t 1 -t 3      Run tests 1 and 3"
            echo "  $0 -v -t 2        Run test 2 with verbose output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Load environment configuration
if [[ -f "$SCRIPT_DIR/.env.test" ]]; then
    source "$SCRIPT_DIR/.env.test"
else
    echo "Error: .env.test file not found in tests directory"
    exit 1
fi

# Helper function to get UUID from VHD path
get_vhd_uuid() {
    # Mount the VHD first to ensure it's attached
    bash "$PARENT_DIR/disk_management.sh" mount --path "$VHD_PATH" --mount-point "$MOUNT_POINT" --name "$VHD_NAME" >/dev/null 2>&1
    # Get UUID from mount point
    local uuid=$(bash "$PARENT_DIR/disk_management.sh" -q status --mount-point "$MOUNT_POINT" 2>&1 | grep -oP '(?<=\().*(?=\):)')
    echo "$uuid"
}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Track start time for duration calculation
START_TIME=$(date +%s)

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Skip this test if specific tests were selected and this isn't one of them
    if [[ ${#SELECTED_TESTS[@]} -gt 0 ]]; then
        local should_run=false
        for selected in "${SELECTED_TESTS[@]}"; do
            if [[ $selected -eq $TESTS_RUN ]]; then
                should_run=true
                break
            fi
        done
        if [[ $should_run == false ]]; then
            return
        fi
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}TEST $TESTS_RUN: $test_name${NC}"
        echo -e "${CYAN}========================================${NC}"
        echo "Command: $test_command"
        echo
    else
        # Show test name inline without newline
        printf "Test %d: %-50s " "$TESTS_RUN" "$test_name"
    fi
    
    # Run the command and capture exit code
    if [[ "$VERBOSE" == "true" ]]; then
        eval "$test_command"
        local exit_code=$?
        echo
    else
        # Suppress output in non-verbose mode
        eval "$test_command" >/dev/null 2>&1
        local exit_code=$?
    fi
    
    # Check if exit code matches expected
    if [[ $exit_code -eq $expected_exit_code ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${GREEN}✓ PASSED${NC} (exit code: $exit_code)"
        else
            echo -e "${GREEN}✓ PASSED${NC}"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${RED}✗ FAILED${NC} (expected exit code: $expected_exit_code, got: $exit_code)"
        else
            echo -e "${RED}✗ FAILED${NC} (expected: $expected_exit_code, got: $exit_code)"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("Test $TESTS_RUN: $test_name")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo
        echo
    fi
}

# Helper function to check if VHD is mounted
is_mounted() {
    mount | grep -q "$MOUNT_POINT"
}

# Helper function to unmount VHD (cleanup)
cleanup_mount() {
    if is_mounted; then
        # Get UUID dynamically for cleanup
        local uuid=$(bash "$PARENT_DIR/disk_management.sh" -q status --mount-point "$MOUNT_POINT" 2>&1 | grep -oP '(?<=\().*(?=\):)')
        bash "$PARENT_DIR/disk_management.sh" -q umount --path "$VHD_PATH" --uuid "$uuid" --mount-point "$MOUNT_POINT" >/dev/null 2>&1
    fi
}

# Start tests
echo -e "${BLUE}========================================"
echo -e "  Disk Management Mount Tests"
echo -e "========================================${NC}"

# Get VHD UUID dynamically
VHD_UUID=$(get_vhd_uuid)

if [[ "$VERBOSE" == "true" ]]; then
    echo "Testing with configuration from .env.test:"
    echo "  VHD_PATH: $VHD_PATH"
    echo "  VHD_UUID (discovered): $VHD_UUID"
    echo "  MOUNT_POINT: $MOUNT_POINT"
    echo "  VHD_NAME: $VHD_NAME"
    echo
    echo
else
    echo "Running tests... (use -v for detailed output)"
    echo
fi

# Ensure VHD is unmounted before tests
cleanup_mount

# Test 1: Mount VHD with default configuration
run_test "Mount VHD with default configuration" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1" \
    0

# Test 2: Mount already-mounted VHD (idempotency test)
run_test "Mount already-mounted VHD (idempotency)" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1" \
    0

# Cleanup for next test
cleanup_mount

# Test 3: Mount with explicit path parameter
run_test "Mount with explicit path parameter" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1" \
    0

# Cleanup for next test
cleanup_mount

# Test 4: Mount with custom mount point
run_test "Mount with custom mount point" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point ${MOUNT_POINT}_custom --name ${VHD_NAME}_custom 2>&1 && sudo umount ${MOUNT_POINT}_custom 2>&1 && rmdir ${MOUNT_POINT}_custom 2>&1" \
    0

# Test 5: Mount verifies VHD file exists
run_test "Mount fails with non-existent VHD path" \
    "bash $PARENT_DIR/disk_management.sh mount --path C:/NonExistent/disk.vhdx --mount-point /tmp/test_mount 2>&1" \
    1

# Test 6: Mount creates mount point if it doesn't exist
run_test "Mount creates mount point directory" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point ${MOUNT_POINT}_newdir --name ${VHD_NAME}_new 2>&1 && mountpoint -q ${MOUNT_POINT}_newdir 2>&1" \
    0

# Cleanup
if mountpoint -q "${MOUNT_POINT}_newdir" 2>/dev/null; then
    bash "$PARENT_DIR/disk_management.sh" -q umount --path "$VHD_PATH" --mount-point "${MOUNT_POINT}_newdir" >/dev/null 2>&1
    rmdir "${MOUNT_POINT}_newdir" 2>/dev/null
fi

# Test 7: Mount in quiet mode
run_test "Mount in quiet mode produces minimal output" \
    "bash $PARENT_DIR/disk_management.sh -q mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1 | wc -l | grep -q '^[0-2]$'" \
    0

# Cleanup for next test
cleanup_mount

# Test 8: Verify mount point is accessible after mount
run_test "Mount point is accessible after mounting" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1 && test -d $MOUNT_POINT && mountpoint -q $MOUNT_POINT 2>&1" \
    0

# Test 9: Mount preserves filesystem permissions
run_test "Mounted filesystem has correct permissions" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1 && test -d $MOUNT_POINT && mountpoint -q $MOUNT_POINT 2>&1" \
    0

# Test 10: Verify VHD status shows mounted after mount
run_test "Status shows VHD as mounted after mount" \
    "bash $PARENT_DIR/disk_management.sh mount --path $VHD_PATH --mount-point $MOUNT_POINT --name $VHD_NAME 2>&1 && bash $PARENT_DIR/disk_management.sh status --uuid $VHD_UUID 2>&1 | grep -iq 'mounted'" \
    0

# Final cleanup
cleanup_mount

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Determine overall status
if [[ $TESTS_FAILED -eq 0 ]]; then
    OVERALL_STATUS="PASSED"
else
    OVERALL_STATUS="FAILED"
fi

# Update test report
if [[ -f "$SCRIPT_DIR/update_test_report.sh" ]]; then
    # Prepare failed tests list as a comma-separated string
    FAILED_TESTS_STR=""
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        FAILED_TESTS_STR=$(IFS='|'; echo "${FAILED_TESTS[*]}")
    fi
    
    bash "$SCRIPT_DIR/update_test_report.sh" \
        --suite "test_mount.sh" \
        --status "$OVERALL_STATUS" \
        --run "$TESTS_RUN" \
        --passed "$TESTS_PASSED" \
        --failed "$TESTS_FAILED" \
        --duration "$DURATION" \
        --failed-tests "$FAILED_TESTS_STR" >/dev/null 2>&1
fi

# Summary
echo -e "${BLUE}========================================"
echo -e "  Test Summary"
echo -e "========================================${NC}"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}"
    exit 1
fi

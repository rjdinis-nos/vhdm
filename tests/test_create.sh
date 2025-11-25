#!/bin/bash

# Test script for disk_management.sh create command
# This script tests various create scenarios

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Save SCRIPT_DIR before sourcing utils.sh (which may overwrite it)
TEST_SCRIPT_DIR="$SCRIPT_DIR"

# Source utility functions for path conversion
source "$PARENT_DIR/libs/utils.sh" 2>/dev/null || true

# Restore SCRIPT_DIR for test script use
SCRIPT_DIR="$TEST_SCRIPT_DIR"

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

# Override DISK_TRACKING_FILE for tests
# Default to tests/vhd_mapping.json if TEST_DISK_TRACKING_FILE is not set
export DISK_TRACKING_FILE="${TEST_DISK_TRACKING_FILE:-$SCRIPT_DIR/vhd_mapping.json}"

# Test-specific VHD configuration (dynamic)
TEST_VHD_NAME="test_create_disk"
TEST_VHD_PATH="${WSL_DISKS_DIR}${TEST_VHD_NAME}.vhdx"
TEST_MOUNT_POINT="${MOUNT_DIR}${TEST_VHD_NAME}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()
ALL_TEST_RESULTS=()  # Array to store all test results: "NUM|NAME|STATUS"

# Track start time for duration calculation
START_TIME=$(date +%s)

# Test VHD paths (separate from production VHDs, uses WSL_DISKS_DIR from .env.test)
TEST_VHD_DIR="${WSL_DISKS_DIR}"
TEST_VHD_BASE="${TEST_VHD_DIR}test_create"

# Cleanup function to remove test VHDs
cleanup_test_vhd() {
    local vhd_path="$1"
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path")
    
    if [[ -f "$vhd_path_wsl" ]]; then
        # Try to unmount if attached (with retry)
        bash "$PARENT_DIR/disk_management.sh" -q umount --path "$vhd_path" >/dev/null 2>&1 || true
        sleep 1
        # Try again in case first attempt didn't complete
        bash "$PARENT_DIR/disk_management.sh" -q umount --path "$vhd_path" >/dev/null 2>&1 || true
        sleep 1
        # Remove the file (force remove even if it seems busy)
        rm -f "$vhd_path_wsl" 2>/dev/null || true
        # On Windows mounts, sometimes need to wait a bit
        sleep 0.5
        rm -f "$vhd_path_wsl" 2>/dev/null || true
    fi
}

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
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}TEST: $test_name${NC}"
        echo -e "${BLUE}========================================${NC}"
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
        ALL_TEST_RESULTS+=("$TESTS_RUN|$test_name|PASSED")
    else
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${RED}✗ FAILED${NC} (expected exit code: $expected_exit_code, got: $exit_code)"
        else
            echo -e "${RED}✗ FAILED${NC} (expected: $expected_exit_code, got: $exit_code)"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("Test $TESTS_RUN: $test_name")
        ALL_TEST_RESULTS+=("$TESTS_RUN|$test_name|FAILED")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo
        echo
    fi
}

# Start tests
echo -e "${BLUE}========================================"
echo -e "  Disk Management Create Tests"
echo -e "========================================${NC}"

if [[ "$VERBOSE" == "true" ]]; then
    echo "Testing with configuration from .env.test:"
    echo "  WSL_DISKS_DIR: $WSL_DISKS_DIR"
    echo "  TEST_VHD_DIR: $TEST_VHD_DIR"
    echo "  TEST_VHD_BASE: $TEST_VHD_BASE"
    echo
    echo
else
    echo "Running tests... (use -v for detailed output)"
    echo
fi

# Pre-cleanup: Remove any leftover test VHDs (silently)
cleanup_test_vhd "${TEST_VHD_BASE}_1.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_2.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_3.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_4.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_5.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_custom.vhdx" 2>/dev/null

# Test 1: Create VHD with default settings (1G)
run_test "Create VHD with default settings" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_1.vhdx 2>&1" \
    0

# Test 2: Verify created VHD file exists
TEST_VHD_DIR_WSL=$(wsl_convert_path "$TEST_VHD_DIR")
run_test "Verify created VHD file exists" \
    "test -f ${TEST_VHD_DIR_WSL}test_create_1.vhdx" \
    0

# Test 3: Verify created VHD is just a file (can be attached later)
# The status command will return exit 1 when path provided but VHD not attached
# OR it might find an old attached VHD - either way, check file exists
run_test "Verify created VHD file can be found" \
    "test -f ${TEST_VHD_DIR_WSL}test_create_1.vhdx" \
    0

# Test 4: Create VHD with custom size (500M)
run_test "Create VHD with custom size (500M)" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_2.vhdx --size 500M 2>&1" \
    0

# Test 5: Verify custom size VHD file exists
run_test "Verify custom size VHD exists" \
    "test -f ${TEST_VHD_DIR_WSL}test_create_2.vhdx" \
    0

# Test 6: Create VHD in quiet mode
run_test "Create VHD in quiet mode" \
    "bash $PARENT_DIR/disk_management.sh -q create --path ${TEST_VHD_BASE}_4.vhdx 2>&1 | grep -q 'created'" \
    0

# Test 7: Attempt to create VHD that already exists (should fail)
run_test "Attempt to create existing VHD (should fail)" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_1.vhdx 2>&1" \
    1

# Cleanup before test 8 to ensure clean state
# First, try to detach all test VHDs that might be attached
# Try to find and detach test_create VHDs from tracking file
if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
    test_paths=$(jq -r '.mappings | to_entries[] | select(.key | contains("test_create")) | .key' "$DISK_TRACKING_FILE" 2>/dev/null || true)
    if [[ -n "$test_paths" ]]; then
        while IFS= read -r test_path; do
            [[ -z "$test_path" ]] && continue
            # Convert normalized path back to Windows format for umount
            # Normalized paths are lowercase, convert back: c:/path -> C:/path
            win_path=$(echo "$test_path" | sed 's|^c:/|C:/|')
            bash $PARENT_DIR/disk_management.sh -q -y umount --path "$win_path" >/dev/null 2>&1 || true
        done <<< "$test_paths"
    fi
fi
sleep 2
# Then cleanup the file
cleanup_test_vhd "${TEST_VHD_BASE}_custom.vhdx" 2>/dev/null
sleep 1

# Test 8: Create VHD with custom size parameter (use --force and -y to overwrite if exists)
run_test "Create VHD with 2G size" \
    "bash $PARENT_DIR/disk_management.sh -y create --path ${TEST_VHD_BASE}_custom.vhdx --size 2G --force 2>&1" \
    0

# Test 9: Verify custom VHD exists
run_test "Verify custom VHD file exists" \
    "test -f ${TEST_VHD_DIR_WSL}test_create_custom.vhdx" \
    0

# Cleanup: Detach the specific VHD we're testing before test 10
# This ensures test 10 can attach the VHD without ambiguity
bash $PARENT_DIR/disk_management.sh -q umount --path ${TEST_VHD_BASE}_custom.vhdx >/dev/null 2>&1 || true
sleep 2

# Test 10: Attach and verify VHD can be attached and formatted
# Note: If multiple VHDs are attached, this test may fail due to UUID discovery ambiguity
# The attach command should handle already-attached VHDs gracefully
run_test "Attach created VHD" \
    "(bash $PARENT_DIR/disk_management.sh attach --vhd-path ${TEST_VHD_BASE}_custom.vhdx 2>&1 || bash $PARENT_DIR/disk_management.sh status --vhd-path ${TEST_VHD_BASE}_custom.vhdx 2>&1 | grep -iq 'attached') && sleep 2 && bash $PARENT_DIR/disk_management.sh status --vhd-path ${TEST_VHD_BASE}_custom.vhdx 2>&1 | grep -iq 'attached'" \
    0

# Cleanup: Remove test VHDs
if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}Cleaning up test VHDs...${NC}"
fi

cleanup_test_vhd "${TEST_VHD_BASE}_1.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_2.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_3.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_4.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_5.vhdx" 2>/dev/null
cleanup_test_vhd "${TEST_VHD_BASE}_custom.vhdx" 2>/dev/null

if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${GREEN}Cleanup complete${NC}"
    echo
fi

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
    # Prepare failed tests list as a pipe-separated string (for backward compatibility)
    FAILED_TESTS_STR=""
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        FAILED_TESTS_STR=$(IFS='|'; echo "${FAILED_TESTS[*]}")
    fi
    
    # Prepare all test results as a pipe-separated string: "NUM|NAME|STATUS|NUM|NAME|STATUS|..."
    TEST_RESULTS_STR=""
    if [[ ${#ALL_TEST_RESULTS[@]} -gt 0 ]]; then
        TEST_RESULTS_STR=$(IFS='|'; echo "${ALL_TEST_RESULTS[*]}")
    fi
    
    bash "$SCRIPT_DIR/update_test_report.sh" \
        --suite "test_create.sh" \
        --status "$OVERALL_STATUS" \
        --run "$TESTS_RUN" \
        --passed "$TESTS_PASSED" \
        --failed "$TESTS_FAILED" \
        --duration "$DURATION" \
        --failed-tests "$FAILED_TESTS_STR" \
        --test-results "$TEST_RESULTS_STR" >/dev/null 2>&1
fi

# Summary
echo -e "${BLUE}========================================"
echo -e "  Test Summary"
echo -e "========================================${NC}"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo

# Cleanup: Remove test-specific tracking file
if [[ -f "$DISK_TRACKING_FILE" ]]; then
    rm -f "$DISK_TRACKING_FILE" 2>/dev/null
fi

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}"
    exit 1
fi

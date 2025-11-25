#!/bin/bash

# Test script for vhdm.sh delete command
# This script tests various delete scenarios

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source utility functions for path conversion
source "$PARENT_DIR/libs/utils.sh" 2>/dev/null || true

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
TEST_VHD_NAME="test_delete_disk"
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
TESTS_SKIPPED=0
FAILED_TESTS=()

# Track start time for duration calculation
START_TIME=$(date +%s)

# Test VHD paths (separate from production VHDs, uses WSL_DISKS_DIR from .env.test)
TEST_VHD_DIR="${WSL_DISKS_DIR}"
TEST_VHD_BASE="${TEST_VHD_DIR}test_delete"

# Cleanup function to remove test VHDs
cleanup_test_vhd() {
    local vhd_path="$1"
    local vhd_path_wsl
    vhd_path_wsl=$(wsl_convert_path "$vhd_path")
    
    if [[ -f "$vhd_path_wsl" ]]; then
        # Try to unmount if attached
        bash "$PARENT_DIR/vhdm.sh" -q umount --path "$vhd_path" >/dev/null 2>&1 || true
        # Remove the file
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

# Start tests
echo -e "${BLUE}========================================"
echo -e "  Disk Management Delete Tests"
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

# Test 1: Attempt to delete attached VHD (should fail - VHD must be detached first)
if [[ "$VERBOSE" == "true" ]]; then
    echo "Creating test VHD for test 1..."
fi
bash "$PARENT_DIR/vhdm.sh" -q create --path "${TEST_VHD_BASE}_1.vhdx" --size 100M >/dev/null 2>&1
bash "$PARENT_DIR/vhdm.sh" -q attach --vhd-path "${TEST_VHD_BASE}_1.vhdx" >/dev/null 2>&1

run_test "Attempt to delete attached VHD (should fail)" \
    "bash $PARENT_DIR/vhdm.sh delete --path ${TEST_VHD_BASE}_1.vhdx --force 2>&1" \
    1

# Cleanup test 1 VHD
bash "$PARENT_DIR/vhdm.sh" -q detach --path "${TEST_VHD_BASE}_1.vhdx" >/dev/null 2>&1
bash "$PARENT_DIR/vhdm.sh" -q delete --path "${TEST_VHD_BASE}_1.vhdx" --force >/dev/null 2>&1

# Test 2: Delete detached VHD by path
if [[ "$VERBOSE" == "true" ]]; then
    echo "Creating test VHD for test 2..."
fi
bash "$PARENT_DIR/vhdm.sh" -q create --path "${TEST_VHD_BASE}_2.vhdx" --size 100M >/dev/null 2>&1
# VHDs created by 'create' command are not attached, so no need to detach
# However, if it somehow got attached, try to detach it
# Check if actually attached via lsblk before trying to detach
local vhd_path_wsl
vhd_path_wsl=$(wsl_convert_path "${TEST_VHD_BASE}_2.vhdx")
if lsblk -f -J 2>/dev/null | jq -e --arg path "$vhd_path_wsl" '.blockdevices[] | select(.name != null)' >/dev/null 2>&1; then
    # VHD appears to be attached, try to detach
    bash "$PARENT_DIR/vhdm.sh" -q umount --path "${TEST_VHD_BASE}_2.vhdx" >/dev/null 2>&1 || \
        wsl.exe --unmount "${TEST_VHD_BASE}_2.vhdx" >/dev/null 2>&1 || true
    sleep 1
fi

run_test "Delete detached VHD by path" \
    "bash $PARENT_DIR/vhdm.sh delete --path ${TEST_VHD_BASE}_2.vhdx --force 2>&1" \
    0

# Test 3: Verify VHD file is removed after delete
TEST_VHD_DIR_WSL=$(wsl_convert_path "$TEST_VHD_DIR")
run_test "Verify VHD file is removed after delete" \
    "test ! -f ${TEST_VHD_DIR_WSL}test_delete_2.vhdx" \
    0

# Test 4: Delete with --force flag (skip confirmations)
if [[ "$VERBOSE" == "true" ]]; then
    echo "Creating test VHD for test 4..."
fi
bash "$PARENT_DIR/vhdm.sh" -q create --path "${TEST_VHD_BASE}_3.vhdx" --size 100M >/dev/null 2>&1
# VHDs created by 'create' command are not attached, so no need to detach

run_test "Delete detached VHD with --force flag" \
    "bash $PARENT_DIR/vhdm.sh delete --path ${TEST_VHD_BASE}_3.vhdx --force 2>&1" \
    0

# Test 5: Delete in quiet mode
if [[ "$VERBOSE" == "true" ]]; then
    echo "Creating test VHD for test 5..."
fi
bash "$PARENT_DIR/vhdm.sh" -q create --path "${TEST_VHD_BASE}_4.vhdx" --size 100M >/dev/null 2>&1
# VHDs created by 'create' command are not attached, so no need to detach

run_test "Delete in quiet mode" \
    "bash $PARENT_DIR/vhdm.sh -q delete --path ${TEST_VHD_BASE}_4.vhdx --force 2>&1 | grep -q 'deleted'" \
    0

# Test 6: Attempt to delete non-existent VHD (should fail)
run_test "Attempt to delete non-existent VHD (should fail)" \
    "bash $PARENT_DIR/vhdm.sh delete --path C:/NonExistent/disk.vhdx --force 2>&1" \
    1

# Test 7: Delete with missing required parameter (should fail)
run_test "Delete with missing required parameter (should fail)" \
    "bash $PARENT_DIR/vhdm.sh delete --force 2>&1" \
    1

# Test 8: Create and immediately delete a VHD
if [[ "$VERBOSE" == "true" ]]; then
    echo "Creating test VHD for test 8..."
fi

run_test "Create, detach, and delete a VHD" \
    "bash $PARENT_DIR/vhdm.sh -q create --path ${TEST_VHD_BASE}_temp.vhdx --size 100M >/dev/null 2>&1 && bash $PARENT_DIR/vhdm.sh -q delete --path ${TEST_VHD_BASE}_temp.vhdx --force 2>&1" \
    0

# Test 9: Verify temp VHD is gone
run_test "Verify temp VHD is removed" \
    "test ! -f ${TEST_VHD_DIR_WSL}test_delete_temp.vhdx" \
    0

# Test 10: Attempt to delete already deleted VHD (should fail)
run_test "Attempt to delete already deleted VHD (should fail)" \
    "bash $PARENT_DIR/vhdm.sh delete --path ${TEST_VHD_BASE}_2.vhdx --force 2>&1" \
    1

# Cleanup: Remove any remaining test VHDs
if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}Cleaning up remaining test VHDs...${NC}"
fi

cleanup_test_vhd "${TEST_VHD_BASE}_1.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_2.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_3.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_4.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_temp.vhdx"

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
    # Prepare failed tests list as a comma-separated string
    FAILED_TESTS_STR=""
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        FAILED_TESTS_STR=$(IFS='|'; echo "${FAILED_TESTS[*]}")
    fi
    
    bash "$SCRIPT_DIR/update_test_report.sh" \
        --suite "test_delete.sh" \
        --status "$OVERALL_STATUS" \
        --run "$TESTS_RUN" \
        --passed "$TESTS_PASSED" \
        --failed "$TESTS_FAILED" \
        --duration "$DURATION" \
        --failed-tests "$FAILED_TESTS_STR" >/dev/null 2>&1
fi

# Summary
echo
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

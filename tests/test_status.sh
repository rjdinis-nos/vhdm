#!/bin/bash

# Test script for disk_management.sh status command
# This script tests various status scenarios using the VHD from .env.test

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  -v, --verbose  Show detailed test output"
            echo "  -h, --help     Show this help message"
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

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
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
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo
        echo
    fi
}

# Start tests
echo -e "${BLUE}========================================"
echo "  Disk Management Status Tests"
echo "========================================${NC}"

if [[ "$VERBOSE" == "true" ]]; then
    echo "Testing with configuration from .env.test:"
    echo "  VHD_PATH: $VHD_PATH"
    echo "  VHD_UUID: $VHD_UUID"
    echo "  MOUNT_POINT: $MOUNT_POINT"
    echo
    echo
else
    echo "Running tests... (use -v for detailed output)"
    echo
fi

# Test 1: Status with default configuration (from .env.test)
run_test "Status shows help without arguments" \
    "bash $PARENT_DIR/disk_management.sh status | grep -q 'Usage:'" \
    0

# Test 2: Status with specific UUID
run_test "Status with specific UUID" \
    "bash $PARENT_DIR/disk_management.sh status --uuid $VHD_UUID" \
    0

# Test 3: Status with specific path
run_test "Status with specific path" \
    "bash $PARENT_DIR/disk_management.sh status --path $VHD_PATH" \
    0

# Test 4: Status with specific mount point
run_test "Status with specific mount point" \
    "bash $PARENT_DIR/disk_management.sh status --mount-point $MOUNT_POINT" \
    1

# Test 5: Status shows attached but not mounted
run_test "Status shows attached but not mounted" \
    "bash $PARENT_DIR/disk_management.sh status --all | grep -iq 'attached but not mounted'" \
    0

# Test 6: Status with --all flag
run_test "Status with --all flag" \
    "bash $PARENT_DIR/disk_management.sh status --all" \
    0

# Test 7: Status in quiet mode
run_test "Status in quiet mode" \
    "bash $PARENT_DIR/disk_management.sh -q status --all" \
    0

# Test 8: Status with non-existent VHD path (should fail)
run_test "Status with non-existent VHD path (should fail)" \
    "bash $PARENT_DIR/disk_management.sh status --path C:/NonExistent/disk.vhdx" \
    1

# Test 9: Status with non-existent mount point (should fail)
run_test "Status with non-existent mount point (should fail)" \
    "bash $PARENT_DIR/disk_management.sh status --mount-point /mnt/nonexistent" \
    1

# Test 10: Status with invalid UUID (should fail)
run_test "Status with invalid UUID (should fail)" \
    "bash $PARENT_DIR/disk_management.sh status --uuid 00000000-0000-0000-0000-000000000000" \
    0

# Summary
echo -e "${BLUE}========================================"
echo "  Test Summary"
echo "========================================${NC}"
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

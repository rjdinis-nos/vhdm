#!/bin/bash

# Test script for disk_management.sh delete command
# This script tests various delete scenarios
# NOTE: Delete command is not yet implemented in disk_management.sh

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
            echo
            echo "NOTE: Delete command is not yet implemented in disk_management.sh"
            echo "      This test suite is a placeholder for future implementation."
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
TESTS_SKIPPED=0

# Test VHD paths (separate from production VHDs)
TEST_VHD_DIR="C:/aNOS/VMs/wsl_test/"
TEST_VHD_BASE="${TEST_VHD_DIR}test_delete"

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
        echo -e "${YELLOW}SKIPPED: Delete command not yet implemented${NC}"
        echo
        echo
    else
        # Show test name inline without newline
        printf "Test %d: %-50s " "$TESTS_RUN" "$test_name"
        echo -e "${YELLOW}SKIPPED${NC}"
    fi
    
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# Start tests
echo -e "${BLUE}========================================"
echo -e "  Disk Management Delete Tests"
echo -e "========================================${NC}"

echo -e "${YELLOW}NOTE: Delete command is not yet implemented${NC}"
echo -e "${YELLOW}      These tests are placeholders for future implementation${NC}"
echo

if [[ "$VERBOSE" == "true" ]]; then
    echo "Testing VHD deletion in: $TEST_VHD_DIR"
    echo
    echo
else
    echo "Running tests... (use -v for detailed output)"
    echo
fi

# Test 1: Delete VHD by path (detach and remove file)
run_test "Delete VHD by path" \
    "bash $PARENT_DIR/disk_management.sh delete --path ${TEST_VHD_BASE}_1.vhdx" \
    0

# Test 2: Delete VHD by UUID
run_test "Delete VHD by UUID" \
    "bash $PARENT_DIR/disk_management.sh delete --uuid 12345678-1234-1234-1234-123456789012" \
    0

# Test 3: Delete mounted VHD (should unmount first)
run_test "Delete mounted VHD (should unmount first)" \
    "bash $PARENT_DIR/disk_management.sh delete --path ${TEST_VHD_BASE}_mounted.vhdx" \
    0

# Test 4: Delete with --force flag (skip confirmations)
run_test "Delete with --force flag" \
    "bash $PARENT_DIR/disk_management.sh delete --path ${TEST_VHD_BASE}_2.vhdx --force" \
    0

# Test 5: Delete in quiet mode
run_test "Delete in quiet mode" \
    "bash $PARENT_DIR/disk_management.sh -q delete --path ${TEST_VHD_BASE}_3.vhdx" \
    0

# Test 6: Attempt to delete non-existent VHD (should fail)
run_test "Attempt to delete non-existent VHD (should fail)" \
    "bash $PARENT_DIR/disk_management.sh delete --path C:/NonExistent/disk.vhdx" \
    1

# Test 7: Delete VHD and verify file is removed
run_test "Verify VHD file is removed after delete" \
    "bash $PARENT_DIR/disk_management.sh delete --path ${TEST_VHD_BASE}_4.vhdx && ! test -f /mnt/c/aNOS/VMs/wsl_test/test_delete_4.vhdx" \
    0

# Test 8: Delete attached but not mounted VHD
run_test "Delete attached but not mounted VHD" \
    "bash $PARENT_DIR/disk_management.sh delete --path ${TEST_VHD_BASE}_attached.vhdx" \
    0

# Test 9: Delete with missing required parameter (should fail)
run_test "Delete with missing required parameter (should fail)" \
    "bash $PARENT_DIR/disk_management.sh delete" \
    1

# Test 10: Delete VHD by mount point
run_test "Delete VHD by mount point" \
    "bash $PARENT_DIR/disk_management.sh delete --mount-point /mnt/test_delete" \
    0

# Summary
echo
echo -e "${BLUE}========================================"
echo -e "  Test Summary"
echo -e "========================================${NC}"
echo "Tests run:     $TESTS_RUN"
echo -e "Tests passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Tests skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo

if [[ $TESTS_SKIPPED -gt 0 ]]; then
    echo -e "${YELLOW}All tests skipped - delete command not yet implemented${NC}"
    echo
    echo "To implement the delete command, add the following to disk_management.sh:"
    echo "  1. Add 'delete' to the case statement in show_usage()"
    echo "  2. Implement delete_vhd() function that:"
    echo "     - Accepts --path, --uuid, or --mount-point"
    echo "     - Unmounts VHD if mounted"
    echo "     - Detaches VHD from WSL"
    echo "     - Removes the VHD file"
    echo "     - Supports --force flag to skip confirmations"
    echo "  3. Add 'delete' to the main case statement"
    echo
    exit 2  # Exit code 2 indicates skipped tests
elif [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}"
    exit 1
fi

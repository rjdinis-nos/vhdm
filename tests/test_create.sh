#!/bin/bash

# Test script for disk_management.sh create command
# This script tests various create scenarios

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

# Test VHD paths (separate from production VHDs)
TEST_VHD_DIR="C:/aNOS/VMs/wsl_test/"
TEST_VHD_BASE="${TEST_VHD_DIR}test_create"

# Cleanup function to remove test VHDs
cleanup_test_vhd() {
    local vhd_path="$1"
    local vhd_path_wsl=$(echo "$vhd_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
    
    if [[ -f "$vhd_path_wsl" ]]; then
        # Try to unmount if attached
        bash "$PARENT_DIR/disk_management.sh" -q umount --path "$vhd_path" 2>/dev/null || true
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
    echo "Testing VHD creation in: $TEST_VHD_DIR"
    echo
    echo
else
    echo "Running tests... (use -v for detailed output)"
    echo
fi

# Pre-cleanup: Remove any leftover test VHDs
cleanup_test_vhd "${TEST_VHD_BASE}_1.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_2.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_3.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_4.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_5.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_custom.vhdx"

# Test 1: Create VHD with default settings (1G, ext4)
run_test "Create VHD with default settings" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_1.vhdx --name test_create_1" \
    0

# Test 2: Verify created VHD file exists
run_test "Verify created VHD file exists" \
    "test -f /mnt/c/aNOS/VMs/wsl_test/test_create_1.vhdx" \
    0

# Test 3: Verify created VHD is attached
run_test "Verify created VHD is attached" \
    "bash $PARENT_DIR/disk_management.sh status --path ${TEST_VHD_BASE}_1.vhdx | grep -iq 'attached'" \
    0

# Test 4: Create VHD with custom size (500M)
run_test "Create VHD with custom size (500M)" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_2.vhdx --size 500M --name test_create_2" \
    0

# Test 5: Create VHD with custom filesystem (xfs)
run_test "Create VHD with custom filesystem (xfs)" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_3.vhdx --filesystem xfs --name test_create_3" \
    0

# Test 6: Create VHD in quiet mode
run_test "Create VHD in quiet mode" \
    "bash $PARENT_DIR/disk_management.sh -q create --path ${TEST_VHD_BASE}_4.vhdx --name test_create_4 | grep -q 'created with UUID='" \
    0

# Test 7: Attempt to create VHD that already exists (should fail)
run_test "Attempt to create existing VHD (should fail)" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_1.vhdx --name test_create_1" \
    1

# Test 8: Create VHD with all custom parameters
run_test "Create VHD with all custom parameters" \
    "bash $PARENT_DIR/disk_management.sh create --path ${TEST_VHD_BASE}_custom.vhdx --size 2G --name test_custom --filesystem ext4" \
    0

# Test 9: Verify VHD created with custom params exists
run_test "Verify custom VHD exists" \
    "test -f /mnt/c/aNOS/VMs/wsl_test/test_create_custom.vhdx" \
    0

# Test 10: Verify created VHD has filesystem (can be mounted)
run_test "Verify VHD has filesystem" \
    "bash $PARENT_DIR/disk_management.sh status --path ${TEST_VHD_BASE}_custom.vhdx | grep -iq 'UUID'" \
    0

# Cleanup: Remove test VHDs
if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}Cleaning up test VHDs...${NC}"
fi

cleanup_test_vhd "${TEST_VHD_BASE}_1.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_2.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_3.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_4.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_5.vhdx"
cleanup_test_vhd "${TEST_VHD_BASE}_custom.vhdx"

if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${GREEN}Cleanup complete${NC}"
    echo
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

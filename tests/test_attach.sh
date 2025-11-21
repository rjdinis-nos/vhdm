#!/bin/bash

# Test script for disk_management.sh attach command
# This script tests various attach scenarios using the VHD from .env.test

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

# Test-specific VHD configuration (dynamic)
TEST_VHD_NAME="test_attach_disk"
TEST_VHD_PATH="${WSL_DISKS_DIR}${TEST_VHD_NAME}.vhdx"
TEST_MOUNT_POINT="${MOUNT_DIR}${TEST_VHD_NAME}"

# Helper function to get UUID from VHD path (attach first to ensure it exists)
get_vhd_uuid() {
    local vhd_path="$1"
    local vhd_name="$2"
    
    # Attach the VHD first to ensure it's available
    bash "$PARENT_DIR/disk_management.sh" attach --path "$vhd_path" --name "$vhd_name" >/dev/null 2>&1
    # Get UUID from path
    local uuid=$(bash "$PARENT_DIR/disk_management.sh" -q status --path "$vhd_path" 2>&1 | grep -oP '(?<=\().*(?=\):)')
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
        printf "Test %2d: %-50s " "$TESTS_RUN" "$test_name"
    fi
    
    # Capture output and exit code
    local output
    local exit_code
    
    if [[ "$VERBOSE" == "true" ]]; then
        # In verbose mode, show the output
        output=$(eval "$test_command" 2>&1)
        exit_code=$?
        echo "$output"
        echo
    else
        # In normal mode, suppress output
        output=$(eval "$test_command" 2>&1)
        exit_code=$?
    fi
    
    # Check if test passed
    if [[ $exit_code -eq $expected_exit_code ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${GREEN}[PASS]${NC} Exit code: $exit_code (expected: $expected_exit_code)"
            echo
        else
            echo -e "${GREEN}[PASS]${NC}"
        fi
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("Test $TESTS_RUN: $test_name")
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${RED}[FAIL]${NC} Exit code: $exit_code (expected: $expected_exit_code)"
            echo
        else
            echo -e "${RED}[FAIL]${NC}"
            # Show output on failure even in concise mode
            echo "  Output: $output"
        fi
    fi
}

# Header
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VHD Attach Command Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo "Test VHD: $TEST_VHD_PATH"
echo "Mount Point: $TEST_MOUNT_POINT"
echo
echo -e "${BLUE}========================================${NC}"
echo

# Ensure VHD is detached before starting tests
echo "Preparing test environment..."
# Discover UUID dynamically
VHD_UUID=$(get_vhd_uuid "$TEST_VHD_PATH" "$TEST_VHD_NAME")
echo "Discovered VHD UUID: $VHD_UUID"
"$PARENT_DIR/disk_management.sh" umount --uuid "$VHD_UUID" >/dev/null 2>&1
sleep 1
echo "Environment ready."
echo

# Test 1: Basic attach with path
run_test "Attach VHD with --path option" \
    "$PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'attached'" \
    0

# Test 2: Idempotency - attach already-attached VHD
run_test "Attach already-attached VHD (idempotency)" \
    "$PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'already attached'" \
    0

# Test 3: Attach with custom name
run_test "Attach VHD with custom --name" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" --name testdisk 2>&1 | grep -q 'attached'" \
    0

# Test 4: Verify VHD appears in status after attach
run_test "Verify attached VHD appears in status" \
    "$PARENT_DIR/disk_management.sh status --uuid \"$VHD_UUID\" 2>&1 | grep -q 'VHD is attached'" \
    0

# Test 5: Verify VHD is NOT mounted after attach (attach should not mount)
run_test "Verify VHD is not mounted after attach" \
    "$PARENT_DIR/disk_management.sh status --uuid \"$VHD_UUID\" 2>&1 | grep -q '<not mounted>'" \
    0

# Test 6: Quiet mode output
run_test "Attach in quiet mode produces machine-readable output" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh -q attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'attached'" \
    0

# Test 7: Debug mode output
run_test "Attach in debug mode shows commands" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh -d attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q '\\[DEBUG\\]'" \
    0

# Test 8: Error handling - non-existent path
run_test "Error handling: non-existent VHD path" \
    "$PARENT_DIR/disk_management.sh attach --path \"C:/NonExistent/fake.vhdx\" 2>&1" \
    1

# Test 9: Error handling - missing path parameter
run_test "Error handling: missing --path parameter" \
    "$PARENT_DIR/disk_management.sh attach 2>&1" \
    1

# Test 10: Attach detaches and re-attaches successfully
run_test "Detach and re-attach VHD successfully" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'attached'" \
    0

# Test 11: UUID detection after attach
run_test "UUID is detected and reported after attach" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'UUID:'" \
    0

# Test 12: Device name reported after attach
run_test "Device name is reported after attach" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'Device: /dev/sd'" \
    0

# Test 13: Attach shows completion message
run_test "Attach shows completion message" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'Attach operation completed'" \
    0

# Test 14: Combined quiet and debug mode
run_test "Combined quiet and debug mode works" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh -q -d attach --path \"$TEST_VHD_PATH\" 2>&1 | grep -q 'attached'" \
    0

# Test 15: Attach with Windows path using backslashes
run_test "Attach with Windows path (backslash format)" \
    "$PARENT_DIR/disk_management.sh umount --uuid \"$VHD_UUID\" >/dev/null 2>&1; $PARENT_DIR/disk_management.sh attach --path \"$(echo $TEST_VHD_PATH | sed 's|/|\\\\|g')\" 2>&1 | grep -q 'attached'" \
    0

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test Results${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "Duration:     ${DURATION}s"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    echo
    exit 0
fi

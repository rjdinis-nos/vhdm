#!/bin/bash

# Test runner script - Runs all test suites
# This script executes all test files in sequence and reports overall results

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
VERBOSE=false
STOP_ON_FAILURE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--stop-on-failure)
            STOP_ON_FAILURE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  -v, --verbose          Show detailed test output for all suites"
            echo "  -s, --stop-on-failure  Stop execution if any test suite fails"
            echo "  -h, --help             Show this help message"
            echo
            echo "This script runs all test suites in sequence:"
            echo "  - test_status.sh"
            echo "  - test_attach.sh"
            echo "  - test_mount.sh"
            echo "  - test_umount.sh"
            echo "  - test_create.sh"
            echo "  - test_delete.sh"
            echo "  - test_resize.sh"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Test suites to run (in order)
TEST_SUITES=(
    "test_status.sh"
    "test_attach.sh"
    "test_mount.sh"
    "test_umount.sh"
    "test_create.sh"
    "test_delete.sh"
    "test_resize.sh"
)

# Counters
SUITES_TOTAL=${#TEST_SUITES[@]}
SUITES_PASSED=0
SUITES_FAILED=0
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Array to track failed suites
FAILED_SUITES=()

# Header
echo -e "${BLUE}========================================"
echo -e "  WSL VHD Disk Management"
echo -e "  Complete Test Suite Runner"
echo -e "========================================${NC}"
echo "Running $SUITES_TOTAL test suites..."
echo

# Run each test suite
for test_suite in "${TEST_SUITES[@]}"; do
    test_path="$SCRIPT_DIR/$test_suite"
    
    if [[ ! -f "$test_path" ]]; then
        echo -e "${YELLOW}⚠ Skipping $test_suite (file not found)${NC}"
        echo
        continue
    fi
    
    if [[ ! -x "$test_path" ]]; then
        echo -e "${YELLOW}⚠ Skipping $test_suite (not executable)${NC}"
        echo
        continue
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Running: $test_suite${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Run the test suite
    if [[ "$VERBOSE" == "true" ]]; then
        "$test_path" -v
    else
        "$test_path"
    fi
    
    exit_code=$?
    
    # Parse test results from the output (assuming test scripts output "Tests run: X")
    # This is a simple approach; adjust if needed
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ $test_suite: PASSED${NC}"
        SUITES_PASSED=$((SUITES_PASSED + 1))
    else
        echo -e "${RED}✗ $test_suite: FAILED${NC}"
        SUITES_FAILED=$((SUITES_FAILED + 1))
        FAILED_SUITES+=("$test_suite")
        
        if [[ "$STOP_ON_FAILURE" == "true" ]]; then
            echo
            echo -e "${RED}Stopping execution due to test failure${NC}"
            break
        fi
    fi
    
    echo
done

# Summary
echo -e "${BLUE}========================================"
echo -e "  Overall Test Summary"
echo -e "========================================${NC}"
echo "Test Suites:"
echo -e "  Total:  $SUITES_TOTAL"
echo -e "  Passed: ${GREEN}$SUITES_PASSED${NC}"
echo -e "  Failed: ${RED}$SUITES_FAILED${NC}"

if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
    echo
    echo -e "${RED}Failed Test Suites:${NC}"
    for suite in "${FAILED_SUITES[@]}"; do
        echo -e "  ${RED}✗${NC} $suite"
    done
fi

echo

if [[ $SUITES_FAILED -eq 0 ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  All test suites passed! ✓${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  Some test suites failed! ✗${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi

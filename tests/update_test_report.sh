#!/bin/bash

# Script to update the test report with test results
# Called by test scripts to log their execution results
# Uses test_report.json as the source of truth and generates test_report.md from it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/test_report.md"
JSON_FILE="$SCRIPT_DIR/test_report.json"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 --suite SUITE_NAME --status STATUS --run COUNT --passed COUNT --failed COUNT --duration SECONDS [--failed-tests LIST] [--test-results LIST]

Updates the test report with results from a test suite execution.

Options:
  --suite NAME           Test suite name (e.g., test_status.sh)
  --status STATUS        Overall status (PASSED or FAILED)
  --run COUNT            Number of tests run
  --passed COUNT         Number of tests passed
  --failed COUNT         Number of tests failed
  --duration SEC         Test execution duration in seconds
  --failed-tests LIST    Pipe-separated list of failed test names (optional, deprecated)
  --test-results LIST     Pipe-separated list of all test results in format: "NUM|NAME|STATUS" (optional)

Example:
  $0 --suite test_status.sh --status PASSED --run 10 --passed 10 --failed 0 --duration 5
  $0 --suite test_mount.sh --status FAILED --run 10 --passed 8 --failed 2 --duration 7 \\
     --failed-tests "Test 3: Mount failure|Test 7: Permission issue"
  $0 --suite test_status.sh --status PASSED --run 10 --passed 10 --failed 0 --duration 5 \\
     --test-results "1|Status shows help|PASSED|2|Status with UUID|PASSED|3|Status with path|PASSED"
EOF
}

# Function to get category for a test suite
get_category() {
    local suite="$1"
    case "$suite" in
        test_status.sh)
            echo "Status & Query"
            ;;
        test_create.sh|test_delete.sh|test_resize.sh)
            echo "Lifecycle Operations"
            ;;
        test_attach.sh|test_detach.sh)
            echo "Attachment Operations"
            ;;
        test_mount.sh|test_umount.sh)
            echo "Mount Operations"
            ;;
        *)
            echo "Other"
            ;;
    esac
}

# Parse command line arguments
SUITE_NAME=""
STATUS=""
TESTS_RUN=""
TESTS_PASSED=""
TESTS_FAILED=""
DURATION=""
FAILED_TESTS_LIST=""
TEST_RESULTS_LIST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --suite)
            SUITE_NAME="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --run)
            TESTS_RUN="$2"
            shift 2
            ;;
        --passed)
            TESTS_PASSED="$2"
            shift 2
            ;;
        --failed)
            TESTS_FAILED="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --failed-tests)
            FAILED_TESTS_LIST="$2"
            shift 2
            ;;
        --test-results)
            TEST_RESULTS_LIST="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SUITE_NAME" ]] || [[ -z "$STATUS" ]] || [[ -z "$TESTS_RUN" ]] || \
   [[ -z "$TESTS_PASSED" ]] || [[ -z "$TESTS_FAILED" ]] || [[ -z "$DURATION" ]]; then
    echo "Error: Missing required arguments"
    show_usage
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq to use this script."
    exit 1
fi

# Get current timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
DATE_ONLY=$(date "+%Y-%m-%d")

# Format status with emoji
if [[ "$STATUS" == "PASSED" ]]; then
    STATUS_DISPLAY="✓ PASSED"
else
    STATUS_DISPLAY="✗ FAILED"
fi

# Get category for this suite
CATEGORY=$(get_category "$SUITE_NAME")

# Parse test results - prefer --test-results if provided, otherwise fall back to --failed-tests
declare -a CURRENT_TEST_RESULTS

if [[ -n "$TEST_RESULTS_LIST" ]]; then
    # Parse test results in format "NUM|NAME|STATUS|NUM|NAME|STATUS|..."
    IFS='|' read -ra RESULTS_ARRAY <<< "$TEST_RESULTS_LIST"
    i=0
    while [[ $i -lt ${#RESULTS_ARRAY[@]} ]]; do
        test_num="${RESULTS_ARRAY[$i]}"
        test_name="${RESULTS_ARRAY[$((i+1))]}"
        test_status="${RESULTS_ARRAY[$((i+2))]}"
        
        # Normalize status format
        if [[ "$test_status" == "PASSED" ]] || [[ "$test_status" == "✓ PASSED" ]]; then
            status_display="PASSED"
        elif [[ "$test_status" == "FAILED" ]] || [[ "$test_status" == "✗ FAILED" ]]; then
            status_display="FAILED"
        else
            status_display="$test_status"
        fi
        
        CURRENT_TEST_RESULTS+=("$test_num|$test_name|$status_display")
        i=$((i+3))
    done
else
    # Fall back to parsing failed tests (backward compatibility)
    declare -A FAILED_TEST_MAP
    if [[ -n "$FAILED_TESTS_LIST" ]]; then
        IFS='|' read -ra FAILED_ARRAY <<< "$FAILED_TESTS_LIST"
        for failed_test in "${FAILED_ARRAY[@]}"; do
            # Extract test number from "Test N: Test name" format
            if [[ "$failed_test" =~ Test[[:space:]]+([0-9]+): ]]; then
                test_num="${BASH_REMATCH[1]}"
                # Extract test name (everything after "Test N: ")
                test_name="${failed_test#Test $test_num: }"
                FAILED_TEST_MAP["$test_num"]="$test_name"
            fi
        done
    fi
    
    # Store individual test results for this suite
    # Format: "test_num|test_name|status"
    for ((i=1; i<=TESTS_RUN; i++)); do
        if [[ -n "${FAILED_TEST_MAP[$i]}" ]]; then
            # This test failed
            CURRENT_TEST_RESULTS+=("$i|${FAILED_TEST_MAP[$i]}|FAILED")
        else
            # This test passed (we don't have the name, so we'll use a placeholder)
            CURRENT_TEST_RESULTS+=("$i|Test $i|PASSED")
        fi
    done
fi

# Initialize JSON file if it doesn't exist
if [[ ! -f "$JSON_FILE" ]]; then
    echo '{"suites":{}}' > "$JSON_FILE"
fi

# Read existing JSON data
JSON_DATA=$(cat "$JSON_FILE")

# Build test results array using jq for proper JSON escaping
TEST_RESULTS_JSON="[]"
for test_result in "${CURRENT_TEST_RESULTS[@]}"; do
    IFS='|' read -r test_num test_name test_status <<< "$test_result"
    # Use jq to properly escape and build JSON
    TEST_RESULTS_JSON=$(echo "$TEST_RESULTS_JSON" | jq --argjson num "$test_num" --arg name "$test_name" --arg status "$test_status" '. += [{"number": $num, "name": $name, "status": $status}]')
done

# Update the JSON file with new suite data
JSON_DATA=$(echo "$JSON_DATA" | jq --arg suite "$SUITE_NAME" \
    --arg date "$DATE_ONLY" \
    --arg status "$STATUS_DISPLAY" \
    --argjson run "$TESTS_RUN" \
    --argjson passed "$TESTS_PASSED" \
    --argjson failed "$TESTS_FAILED" \
    --arg duration "${DURATION}s" \
    --argjson test_results "$TEST_RESULTS_JSON" \
    '.suites[$suite] = {
        "last_run": $date,
        "status": $status,
        "tests_run": $run,
        "tests_passed": $passed,
        "tests_failed": $failed,
        "duration": $duration,
        "test_results": $test_results
    }')

# Write updated JSON back to file
echo "$JSON_DATA" > "$JSON_FILE"

# Function to create anchor ID from suite name
create_anchor() {
    local suite="$1"
    # Remove .sh extension, convert to lowercase, replace dots/dashes with hyphens
    echo "$suite" | sed 's/\.sh$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Generate markdown report from JSON
{
    echo "# WSL VHD Disk Management - Test Report"
    echo ""
    echo "Last Updated: $TIMESTAMP"
    echo ""
    echo "<a id=\"test-suite-summary\"></a>"
    echo "## Test Suite Summary"
    echo ""
    echo "| Test Suite | Last Run | Status | Tests Run | Passed | Failed | Duration |"
    echo "|------------|----------|--------|-----------|--------|--------|----------|"
    
    # Get all suite names from JSON and sort them
    SUITE_NAMES=$(echo "$JSON_DATA" | jq -r '.suites | keys[]' | sort)
    
    # Output summary table
    while IFS= read -r suite; do
        last_run=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].last_run")
        status=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].status")
        tests_run=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].tests_run")
        tests_passed=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].tests_passed")
        tests_failed=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].tests_failed")
        duration=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].duration")
        
        # Add color styling to status
        if [[ "$status" =~ ✓.*PASSED ]]; then
            status_display="<span style=\"color: green; font-weight: bold;\">$status</span>"
        else
            status_display="<span style=\"color: red; font-weight: bold;\">$status</span>"
        fi
        
        anchor=$(create_anchor "$suite")
        echo "| [$suite](#$anchor) | $last_run | $status_display | $tests_run | $tests_passed | $tests_failed | $duration |"
    done <<< "$SUITE_NAMES"
    
    echo ""
    
    # Output detailed sections for each suite
    while IFS= read -r suite; do
        last_run=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].last_run")
        status=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].status")
        tests_run=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].tests_run")
        tests_passed=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].tests_passed")
        tests_failed=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].tests_failed")
        duration=$(echo "$JSON_DATA" | jq -r ".suites[\"$suite\"].duration")
        
        anchor=$(create_anchor "$suite")
        
        # Determine status badge color
        if [[ "$status" =~ ✓.*PASSED ]]; then
            status_badge="![PASSED](https://img.shields.io/badge/status-PASSED-brightgreen)"
        else
            status_badge="![FAILED](https://img.shields.io/badge/status-FAILED-red)"
        fi
        
        # Suite header with anchor and improved formatting
        echo "<a id=\"$anchor\"></a>"
        echo "### $suite $status_badge"
        echo ""
        echo "[↑ Back to Summary](#test-suite-summary)"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| **Last Run** | $last_run |"
        echo "| **Status** | $status |"
        echo "| **Tests Run** | $tests_run |"
        echo "| **Passed** | <span style=\"color: green;\">$tests_passed</span> |"
        echo "| **Failed** | <span style=\"color: red;\">$tests_failed</span> |"
        echo "| **Duration** | $duration |"
        echo ""
        
        # Test results table with improved formatting
        echo "#### Test Results"
        echo ""
        echo "| # | Test Name | Status |"
        echo "|---|-----------|--------|"
        
        # Get test results from JSON, sort by test number numerically
        TEST_RESULTS_COUNT=$(echo "$JSON_DATA" | jq ".suites[\"$suite\"].test_results // [] | length")
        
        if [[ "$TEST_RESULTS_COUNT" -gt 0 ]]; then
            # Get test results sorted by number
            TEST_RESULTS=$(echo "$JSON_DATA" | jq -c ".suites[\"$suite\"].test_results // [] | sort_by(.number) | .[]")
            
            while IFS= read -r test_result; do
                test_num=$(echo "$test_result" | jq -r '.number')
                test_name=$(echo "$test_result" | jq -r '.name')
                test_status=$(echo "$test_result" | jq -r '.status')
                
                # Format status display
                if [[ "$test_status" == "PASSED" ]]; then
                    status_display="<span style=\"color: green; font-weight: bold;\">✓ PASSED</span>"
                else
                    status_display="<span style=\"color: red; font-weight: bold;\">✗ FAILED</span>"
                fi
                
                echo "| **$test_num** | $test_name | $status_display |"
            done <<< "$TEST_RESULTS"
        else
            # If no individual test results stored, create placeholders
            for ((i=1; i<=tests_run; i++)); do
                echo "| **$i** | Test $i | <span style=\"color: green; font-weight: bold;\">✓ PASSED</span> |"
            done
        fi
        
        echo ""
    done <<< "$SUITE_NAMES"
    
    echo "---"
    echo "*This report is automatically generated and updated when test suites are executed.*"
} > "$REPORT_FILE"

echo "Test report updated successfully: $REPORT_FILE"
exit 0

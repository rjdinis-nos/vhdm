#!/bin/bash

# Script to update the test report with test results
# Called by test scripts to log their execution results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/test_report.md"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 --suite SUITE_NAME --status STATUS --run COUNT --passed COUNT --failed COUNT --duration SECONDS [--failed-tests LIST]

Updates the test report with results from a test suite execution.

Options:
  --suite NAME           Test suite name (e.g., test_status.sh)
  --status STATUS        Overall status (PASSED or FAILED)
  --run COUNT            Number of tests run
  --passed COUNT         Number of tests passed
  --failed COUNT         Number of tests failed
  --duration SEC         Test execution duration in seconds
  --failed-tests LIST    Pipe-separated list of failed test names (optional)

Example:
  $0 --suite test_status.sh --status PASSED --run 10 --passed 10 --failed 0 --duration 5
  $0 --suite test_mount.sh --status FAILED --run 10 --passed 8 --failed 2 --duration 7 \\
     --failed-tests "Test 3: Mount failure|Test 7: Permission issue"
EOF
}

# Parse command line arguments
SUITE_NAME=""
STATUS=""
TESTS_RUN=""
TESTS_PASSED=""
TESTS_FAILED=""
DURATION=""
FAILED_TESTS_LIST=""

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

# Get current timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
DATE_ONLY=$(date "+%Y-%m-%d")

# Format status with emoji
if [[ "$STATUS" == "PASSED" ]]; then
    STATUS_DISPLAY="✓ PASSED"
else
    STATUS_DISPLAY="✗ FAILED"
fi

# Create temp file
TEMP_FILE=$(mktemp)

# Read the current report and update it
if [[ ! -f "$REPORT_FILE" ]]; then
    echo "Error: Report file not found at $REPORT_FILE"
    exit 1
fi

# Flag to track if we're updating the summary table or history section
IN_SUMMARY_TABLE=false
IN_HISTORY_SECTION=false
SUMMARY_UPDATED=false
SUITE_FOUND=false

while IFS= read -r line; do
    # Update "Last Updated" line
    if [[ "$line" =~ ^Last\ Updated: ]]; then
        echo "Last Updated: $TIMESTAMP" >> "$TEMP_FILE"
        continue
    fi
    
    # Detect summary table
    if [[ "$line" =~ ^\|\ Test\ Suite\ \| ]]; then
        IN_SUMMARY_TABLE=true
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Handle summary table separator
    if [[ "$IN_SUMMARY_TABLE" == true ]] && [[ "$line" =~ ^\|[-\|\ ]+\| ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    
    # Update matching suite in summary table
    if [[ "$IN_SUMMARY_TABLE" == true ]] && [[ "$line" =~ ^\|\ $SUITE_NAME\ \| ]]; then
        SUITE_FOUND=true
        echo "| $SUITE_NAME | $DATE_ONLY | $STATUS_DISPLAY | $TESTS_RUN | $TESTS_PASSED | $TESTS_FAILED | ${DURATION}s |" >> "$TEMP_FILE"
        continue
    fi
    
    # End of summary table (empty line after table)
    if [[ "$IN_SUMMARY_TABLE" == true ]] && [[ -z "$line" || "$line" =~ ^## ]]; then
        IN_SUMMARY_TABLE=false
        SUMMARY_UPDATED=true
    fi
    
    # Detect history section
    if [[ "$line" =~ ^##\ Test\ History ]]; then
        IN_HISTORY_SECTION=true
        echo "$line" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        # Add new history entry at the top
        echo "### $TIMESTAMP - $SUITE_NAME" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "- **Status:** $STATUS_DISPLAY" >> "$TEMP_FILE"
        echo "- **Tests Run:** $TESTS_RUN" >> "$TEMP_FILE"
        echo "- **Tests Passed:** $TESTS_PASSED" >> "$TEMP_FILE"
        echo "- **Tests Failed:** $TESTS_FAILED" >> "$TEMP_FILE"
        echo "- **Duration:** ${DURATION}s" >> "$TEMP_FILE"
        
        # Add failed tests list if there are any failures
        if [[ -n "$FAILED_TESTS_LIST" ]] && [[ "$TESTS_FAILED" -gt 0 ]]; then
            echo "" >> "$TEMP_FILE"
            echo "**Failed Tests:**" >> "$TEMP_FILE"
            # Split the pipe-separated list and format as bullet points
            IFS='|' read -ra FAILED_ARRAY <<< "$FAILED_TESTS_LIST"
            for failed_test in "${FAILED_ARRAY[@]}"; do
                echo "- $failed_test" >> "$TEMP_FILE"
            done
        fi
        
        echo "" >> "$TEMP_FILE"
        continue
    fi
    
    # Skip the "No test runs recorded yet" line if we're adding history
    if [[ "$IN_HISTORY_SECTION" == true ]] && [[ "$line" =~ ^\*No\ test\ runs ]]; then
        continue
    fi
    
    # Write all other lines as-is
    echo "$line" >> "$TEMP_FILE"
done < "$REPORT_FILE"

# Check if suite was found in summary table
if [[ "$SUITE_FOUND" == false ]]; then
    echo "Warning: Suite '$SUITE_NAME' not found in summary table. Report may be malformed."
fi

# Replace the original report with updated version
mv "$TEMP_FILE" "$REPORT_FILE"

echo "Test report updated successfully: $REPORT_FILE"
exit 0
